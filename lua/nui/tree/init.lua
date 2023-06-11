local Object = require("nui.object")
local _ = require("nui.utils")._
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type
local tree_util = require("nui.tree.util")

-- returns id of the first window that contains the buffer
---@param bufnr number
---@return number winid
local function get_winid(bufnr)
  return vim.fn.win_findbuf(bufnr)[1]
end

---@param nodes NuiTree.Node[]
---@param parent_node? NuiTree.Node
---@param get_node_id nui_tree_get_node_id
---@return { by_id: table<string, NuiTree.Node>, root_ids: string[] }
local function initialize_nodes(nodes, parent_node, get_node_id)
  local start_depth = parent_node and parent_node:get_depth() + 1 or 1

  ---@type table<string, NuiTree.Node>
  local by_id = {}
  ---@type string[]
  local root_ids = {}

  ---@param node NuiTree.Node
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

---@class NuiTree.Node
---@field _id string
---@field _depth integer
---@field _parent_id? string
---@field _child_ids? string[]
---@field __children? NuiTree.Node[]
---@field [string] any
local TreeNode = {
  super = nil,
}

---@alias NuiTreeNode NuiTree.Node

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

--luacheck: push no max line length

---@alias nui_tree_get_node_id fun(node: NuiTree.Node): string
---@alias nui_tree_prepare_node fun(node: NuiTree.Node, parent_node?: NuiTree.Node): nil | string | string[] | NuiLine | NuiLine[]
---@alias nui_tree_internal { buf_options: table<string,any>, win_options: table<string,any>, get_node_id: nui_tree_get_node_id, prepare_node: nui_tree_prepare_node, track_tree_linenr?: boolean }

--luacheck: pop

---@class nui_tree_options
---@field bufnr integer
---@field ns_id? string|integer
---@field nodes? NuiTree.Node[]
---@field get_node_id? fun(node: NuiTree.Node): string
---@field prepare_node? fun(node: NuiTree.Node, parent_node?: NuiTree.Node): nil|string|string[]|NuiLine|NuiLine[]

---@class NuiTree
---@field bufnr integer
---@field nodes { by_id: table<string,NuiTree.Node>, root_ids: string[] }
---@field ns_id integer
---@field private _ nui_tree_internal
---@field winid number # @deprecated
local Tree = Object("NuiTree")

---@param options nui_tree_options
function Tree:init(options)
  ---@deprecated
  if options.winid then
    if not vim.api.nvim_win_is_valid(options.winid) then
      error("invalid winid " .. options.winid)
    end

    self.winid = options.winid
    self.bufnr = vim.api.nvim_win_get_buf(self.winid)
  end

  if options.bufnr then
    if not vim.api.nvim_buf_is_valid(options.bufnr) then
      error("invalid bufnr " .. options.bufnr)
    end

    self.bufnr = options.bufnr
    self.winid = nil
  end

  if not self.bufnr then
    error("missing bufnr")
  end

  self.ns_id = _.normalize_namespace_id(options.ns_id)

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
    ---@deprecated
    win_options = vim.tbl_extend("force", {
      foldcolumn = "0",
      foldmethod = "manual",
      wrap = false,
    }, defaults(options.win_options, {})),
    get_node_id = defaults(options.get_node_id, tree_util.default_get_node_id),
    prepare_node = defaults(options.prepare_node, tree_util.default_prepare_node),
    track_tree_linenr = nil,
  }

  _.set_buf_options(self.bufnr, self._.buf_options)

  ---@deprecated
  if self.winid then
    _.set_win_options(self.winid, self._.win_options)
  end

  self:set_nodes(defaults(options.nodes, {}))
end

---@generic D : table
---@param data D data table
---@param children? NuiTree.Node[]
---@return NuiTree.Node|D
function Tree.Node(data, children)
  ---@type NuiTree.Node
  local self = {
    __children = children,
    _initialized = false,
    _is_expanded = false,
    _child_ids = nil,
    _parent_id = nil,
    ---@diagnostic disable-next-line: assign-type-mismatch
    _depth = nil,
    ---@diagnostic disable-next-line: assign-type-mismatch
    _id = nil,
  }

  self = setmetatable(vim.tbl_extend("keep", self, data), {
    __index = TreeNode,
    __name = "NuiTree.Node",
  })

  return self
end

---@param node_id_or_linenr? string | number
---@return NuiTree.Node|nil node
---@return number|nil linenr
function Tree:get_node(node_id_or_linenr)
  if is_type("string", node_id_or_linenr) then
    return self.nodes.by_id[node_id_or_linenr], unpack(self._content.linenr_by_node_id[node_id_or_linenr] or {})
  end

  local winid = get_winid(self.bufnr)
  local linenr = node_id_or_linenr or vim.api.nvim_win_get_cursor(winid)[1]
  local node_id = self._content.node_id_by_linenr[linenr]
  return self.nodes.by_id[node_id], unpack(self._content.linenr_by_node_id[node_id] or {})
end

---@param parent_id? string parent node's id
---@return NuiTree.Node[] nodes
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

---@param nodes NuiTree.Node[]
---@param parent_node? NuiTree.Node
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

---@param nodes NuiTree.Node[]
---@param parent_id? string parent node's id
function Tree:set_nodes(nodes, parent_id)
  --luacheck: push no max line length

  ---@type { linenr: {[1]?:integer,[2]?:integer}, lines: (string|NuiLine)[], node_id_by_linenr: table<number,string>, linenr_by_node_id: table<string, {[1]:integer,[2]:integer}> }
  self._content = {
    linenr = self._content and self._content.linenr or {},
    lines = {},
    node_id_by_linenr = {},
    linenr_by_node_id = {},
  }

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

---@param node NuiTree.Node
---@param parent_id? string parent node's id
function Tree:add_node(node, parent_id)
  local parent_node = self.nodes.by_id[parent_id]
  if parent_id and not parent_node then
    error("invalid parent_id " .. parent_id)
  end

  self:_add_nodes({ node }, parent_node)
end

local function remove_node(tree, node_id)
  local node = tree.nodes.by_id[node_id]
  if node:has_children() then
    for _, child_id in ipairs(node._child_ids) do
      -- We might want to store the nodes and return them with the node itself?
      -- We should _really_ not be doing this recursively, but it will work for now
      remove_node(tree, child_id)
    end
  end
  tree.nodes.by_id[node_id] = nil
  return node
end

---@param node_id string
---@return NuiTree.Node
function Tree:remove_node(node_id)
  local node = remove_node(self, node_id)
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

---@param linenr_start number start line number (1-indexed)
function Tree:_prepare_content(linenr_start)
  self._content.lines = {}
  self._content.node_id_by_linenr = {}
  self._content.linenr_by_node_id = {}

  local current_linenr = 1

  local function prepare(node_id, parent_node)
    local node = self.nodes.by_id[node_id]
    if not node then
      return
    end

    local lines = self._.prepare_node(node, parent_node)

    if lines then
      if type(lines) ~= "table" or lines.content then
        ---@type string[]|NuiLine[]
        lines = { lines }
      end
      ---@cast lines -string, -NuiLine

      local linenr = {}
      for _, line in ipairs(lines) do
        self._content.lines[current_linenr] = line
        self._content.node_id_by_linenr[current_linenr + linenr_start - 1] = node:get_id()
        linenr[1] = linenr[1] or (current_linenr + linenr_start - 1)
        linenr[2] = (current_linenr + linenr_start - 1)
        current_linenr = current_linenr + 1
      end
      self._content.linenr_by_node_id[node:get_id()] = linenr
    end

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

  self._content.linenr = { linenr_start, current_linenr - 1 + linenr_start - 1 }
end

---@param linenr_start? number start line number (1-indexed)
function Tree:render(linenr_start)
  if is_type("nil", self._.track_tree_linenr) then
    self._.track_tree_linenr = is_type("number", linenr_start)
  end

  linenr_start = math.max(1, linenr_start or self._content.linenr[1] or 1)

  local prev_linenr = { self._content.linenr[1], self._content.linenr[2] }
  self:_prepare_content(linenr_start)

  _.set_buf_options(self.bufnr, { modifiable = true, readonly = false })

  if self._.track_tree_linenr then
    _.clear_namespace(self.bufnr, self.ns_id, prev_linenr[1], prev_linenr[2])

    -- if linenr_start was shifted downwards,
    -- clear the previously rendered lines above.
    _.clear_lines(
      self.bufnr,
      math.min(linenr_start, prev_linenr[1] or linenr_start),
      prev_linenr[1] and linenr_start - 1 or 0
    )

    -- for initial render, start inserting in a single line.
    -- for subsequent renders, replace the lines from previous render.
    _.render_lines(
      self._content.lines,
      self.bufnr,
      self.ns_id,
      linenr_start,
      prev_linenr[1] and prev_linenr[2] or linenr_start
    )
  else
    _.clear_namespace(self.bufnr, self.ns_id)

    _.render_lines(self._content.lines, self.bufnr, self.ns_id, 1, -1)
  end

  _.set_buf_options(self.bufnr, { modifiable = false, readonly = true })
end

---@alias NuiTree.constructor fun(options: nui_tree_options): NuiTree
---@type NuiTree|NuiTree.constructor
local NuiTree = Tree

return NuiTree
