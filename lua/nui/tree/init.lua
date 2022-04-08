local _ = require("nui.utils")._
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type
local tree_util = require("nui.tree.util")

---@param nodes NuiTreeNode[]
---@param parent_node? NuiTreeNode
---@param get_node_id nui_tree_get_node_id
---@return { by_id: table<string, NuiTreeNode>, root_ids: string[] }
local function initialize_nodes(nodes, parent_node, get_node_id)
  local start_depth = parent_node and parent_node:get_depth() + 1 or 1

  ---@type table<string, NuiTreeNode>
  local by_id = {}
  ---@type string[]
  local root_ids = {}

  ---@param node NuiTreeNode
  ---@param depth number
  local function initialize(node, depth)
    node._depth = depth
    node._id = get_node_id(node)
    node._initialized = true

    local node_id = node:get_id()

    if by_id[node_id] then
      error("duplicate node id" .. node_id)
    end

    by_id[node_id] = node

    if depth == start_depth then
      table.insert(root_ids, node_id)
    end

    if not node.__children or #node.__children == 0 then
      return
    end

    if not node._child_ids then
      node._child_ids = {}
    end

    for _, child_node in ipairs(node.__children) do
      child_node._parent_id = node_id
      initialize(child_node, depth + 1)
      table.insert(node._child_ids, child_node:get_id())
    end

    node.__children = nil
  end

  for _, node in ipairs(nodes) do
    node._parent_id = parent_node and parent_node:get_id() or nil
    initialize(node, start_depth)
  end

  return {
    by_id = by_id,
    root_ids = root_ids,
  }
end

---@class NuiTreeNode
local TreeNode = {
  super = nil,
}

---@return string
function TreeNode:get_id()
  return self._id
end

---@return number
function TreeNode:get_depth()
  return self._depth
end

---@return string|nil
function TreeNode:get_parent_id()
  return self._parent_id
end

---@return boolean
function TreeNode:has_children()
  return #(self._child_ids or self.__children or {}) > 0
end

---@return string[]
function TreeNode:get_child_ids()
  return self._child_ids or {}
end

---@return boolean
function TreeNode:is_expanded()
  return self._is_expanded
end

---@return boolean is_updated
function TreeNode:expand()
  if self:has_children() and not self:is_expanded() then
    self._is_expanded = true
    return true
  end
  return false
end

---@return boolean is_updated
function TreeNode:collapse()
  if self:is_expanded() then
    self._is_expanded = false
    return true
  end
  return false
end

---@param class NuiTree
---@return NuiTree
local function init(class, options)
  ---@type NuiTree
  local self = setmetatable({}, { __index = class })

  local winid = options.winid
  if not winid then
    error("missing winid")
  elseif not vim.api.nvim_win_is_valid(winid) then
    error("invalid winid " .. winid)
  end

  self.winid = winid
  self.bufnr = vim.api.nvim_win_get_buf(self.winid)

  self.ns_id = defaults(options.ns_id, -1)
  if is_type("string", self.ns_id) then
    self.ns_id = vim.api.nvim_create_namespace(self.ns_id)
  end

  self._ = {
    buf_options = vim.tbl_extend("force", {
      bufhidden = "hide",
      buflisted = false,
      buftype = "nofile",
      modifiable = false,
      readonly = true,
      swapfile = false,
      undolevels = 0,
    }, defaults(options.buf_options, {})),
    win_options = vim.tbl_extend("force", {
      foldcolumn = "0",
      foldmethod = "manual",
      wrap = false,
    }, defaults(options.win_options, {})),
    get_node_id = defaults(options.get_node_id, tree_util.default_get_node_id),
    prepare_node = defaults(options.prepare_node, tree_util.default_prepare_node),
  }

  _.set_buf_options(self.bufnr, self._.buf_options)

  _.set_win_options(self.winid, self._.win_options)

  self:set_nodes(defaults(options.nodes, {}))

  return self
end

--luacheck: push no max line length

---@alias nui_tree_get_node_id fun(node: NuiTreeNode): string
---@alias nui_tree_prepare_node fun(node: NuiTreeNode, parent_node?: NuiTreeNode): string | NuiLine
---@alias nui_tree_internal { buf_options: table<string,any>, win_options: table<string,any>, get_node_id: nui_tree_get_node_id, prepare_node: nui_tree_prepare_node }

--luacheck: pop

---@class NuiTree
---@field bufnr number
---@field nodes { by_id: table<string,NuiTreeNode>, root_ids: string[] }
---@field ns_id number
---@field private _ nui_tree_internal
---@field winid number
local Tree = setmetatable({
  super = nil,
}, {
  __call = init,
  __name = "NuiTree",
})

---@generic D : table
---@param data D data table
---@param children NuiTreeNode[]
---@return NuiTreeNode|D
function Tree.Node(data, children)
  ---@type NuiTreeNode
  local self = {
    __children = children,
    _initialized = false,
    _is_expanded = false,
    _child_ids = nil,
    _parent_id = nil,
    _depth = nil,
    _id = nil,
  }

  self = setmetatable(vim.tbl_extend("keep", self, data), {
    __index = TreeNode,
    __name = "NuiTreeNode",
  })

  return self
end

---@param node_id_or_linenr? string | number
---@return NuiTreeNode|nil node
---@return number|nil linenr
function Tree:get_node(node_id_or_linenr)
  if is_type("string", node_id_or_linenr) then
    return self.nodes.by_id[node_id_or_linenr], self._content.linenr_by_node_id[node_id_or_linenr]
  end

  local linenr = node_id_or_linenr or vim.api.nvim_win_get_cursor(self.winid)[1]
  local node_id = self._content.node_id_by_linenr[linenr]
  return self.nodes.by_id[node_id], linenr
end

---@param parent_id? string parent node's id
---@return NuiTreeNode[] nodes
function Tree:get_nodes(parent_id)
  local node_ids = {}

  if parent_id then
    local parent_node = self.nodes.by_id[parent_id]
    if parent_node then
      node_ids = parent_node._child_ids
    end
  else
    node_ids = self.nodes.root_ids
  end

  return vim.tbl_map(function(id)
    return self.nodes.by_id[id]
  end, node_ids or {})
end

---@param nodes NuiTreeNode[]
---@param parent_node? NuiTreeNode
function Tree:_add_nodes(nodes, parent_node)
  local new_nodes = initialize_nodes(nodes, parent_node, self._.get_node_id)

  self.nodes.by_id = vim.tbl_extend("force", self.nodes.by_id, new_nodes.by_id)

  if parent_node then
    if not parent_node._child_ids then
      parent_node._child_ids = {}
    end

    for _, id in ipairs(new_nodes.root_ids) do
      table.insert(parent_node._child_ids, id)
    end
  else
    for _, id in ipairs(new_nodes.root_ids) do
      table.insert(self.nodes.root_ids, id)
    end
  end
end

---@param nodes NuiTreeNode[]
---@param parent_id? string parent node's id
function Tree:set_nodes(nodes, parent_id)
  --luacheck: push no max line length

  ---@type { lines: string[]|NuiLine[], node_id_by_linenr: table<number,string>, linenr_by_node_id: table<string,number> }
  self._content = { lines = {}, node_id_by_linenr = {}, linenr_by_node_id = {} }

  --luacheck: pop

  if not parent_id then
    self.nodes = { by_id = {}, root_ids = {} }
    self:_add_nodes(nodes)
    return
  end

  local parent_node = self.nodes.by_id[parent_id]
  if not parent_node then
    error("invalid parent_id " .. parent_id)
  end

  if parent_node._child_ids then
    for _, node_id in ipairs(parent_node._child_ids) do
      self.nodes.by_id[node_id] = nil
    end

    parent_node._child_ids = nil
  end

  self:_add_nodes(nodes, parent_node)
end

---@param node NuiTreeNode
---@param parent_id? string parent node's id
function Tree:add_node(node, parent_id)
  local parent_node = self.nodes.by_id[parent_id]
  if parent_id and not parent_node then
    error("invalid parent_id " .. parent_id)
  end

  self:_add_nodes({ node }, parent_node)
end

---@param node_id string
---@return NuiTreeNode
function Tree:remove_node(node_id)
  local node = self.nodes.by_id[node_id]
  self.nodes.by_id[node_id] = nil
  local parent_id = node._parent_id
  if parent_id then
    local parent_node = self.nodes.by_id[parent_id]
    parent_node._child_ids = vim.tbl_filter(function(id)
      return id ~= node_id
    end, parent_node._child_ids)
  else
    self.nodes.root_ids = vim.tbl_filter(function(id)
      return id ~= node_id
    end, self.nodes.root_ids)
  end
  return node
end

function Tree:_prepare_content()
  self._content.lines = {}
  self._content.node_id_by_linenr = {}
  self._content.linenr_by_node_id = {}

  local current_linenr = 1

  local function prepare(node_id, parent_node)
    local node = self.nodes.by_id[node_id]
    if not node then
      return
    end

    local line = self._.prepare_node(node, parent_node)
    self._content.lines[current_linenr] = line
    self._content.node_id_by_linenr[current_linenr] = node:get_id()
    self._content.linenr_by_node_id[node:get_id()] = current_linenr
    current_linenr = current_linenr + 1

    if not node:has_children() or not node:is_expanded() then
      return
    end

    for _, child_node_id in ipairs(node:get_child_ids()) do
      prepare(child_node_id, node)
    end
  end

  for _, node_id in ipairs(self.nodes.root_ids) do
    prepare(node_id)
  end
end

function Tree:render()
  self:_prepare_content()

  _.set_buf_options(self.bufnr, { modifiable = true, readonly = false })

  vim.api.nvim_buf_set_lines(
    self.bufnr,
    0,
    -1,
    false,
    vim.tbl_map(function(line)
      if is_type("string", line) then
        return line
      end
      return line:content()
    end, self._content.lines)
  )

  for i, line in ipairs(self._content.lines) do
    if not is_type("string", line) then
      line:highlight(self.bufnr, self.ns_id, i)
    end
  end

  _.set_buf_options(self.bufnr, { modifiable = false, readonly = true })
end

---@alias NuiTree.constructor fun(options: table): NuiTree
---@type NuiTree|NuiTree.constructor
local NuiTree = Tree

return NuiTree
