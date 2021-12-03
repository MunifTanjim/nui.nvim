local NuiLine = require("nui.line")
local _ = require("nui.utils")._
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type

local function initialize_nodes(nodes, parent_node, get_node_id)
  local start_depth = parent_node and parent_node:get_depth() + 1 or 1

  local by_id = {}
  local root_ids = {}

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

local function default_get_node_id(node)
  if node.id then
    return "-" .. node.id
  end

  if node.text then
    return string.format("%s-%s-%s", node._parent_id or "", node._depth, node.text)
  end

  return "-" .. math.random()
end

local function default_prepare_node(node)
  local line = NuiLine()

  line:append(string.rep("  ", node._depth - 1))

  if node:has_children() then
    line:append(node:is_expanded() and " " or " ")
  else
    line:append("  ")
  end

  if not node.text then
    error("missing node.text")
  end

  line:append(node.text)

  return line
end

local TreeNode = {
  name = "NuiTreeNode",
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
  return self._child_ids and #self._child_ids > 0
end

---@return boolean
function TreeNode:is_expanded()
  return self._is_expanded
end

function TreeNode:expand()
  if self:has_children() and not self:is_expanded() then
    self._is_expanded = true
    return true
  end
  return false
end

function TreeNode:collapse()
  if self:is_expanded() then
    self._is_expanded = false
    return true
  end
  return false
end

local Tree = {
  name = "NuiTree",
  super = nil,
}

function Tree.Node(data, children)
  local self = setmetatable(
    vim.tbl_extend("force", data, {
      __children = children,
      _initialized = false,
      _is_expanded = false,
      _child_ids = nil,
      _parent_id = nil,
      _depth = nil,
      _id = nil,
    }),
    { __index = TreeNode }
  )

  return self
end

local function init(class, options)
  local self = setmetatable({}, class)

  local winid = options.winid
  if not winid then
    error("missing winid")
  elseif not vim.api.nvim_win_is_valid(winid) then
    error("invalid winid " .. winid)
  end

  self.winid = winid
  self.bufnr = vim.api.nvim_win_get_buf(self.winid)

  self.buf_options = vim.tbl_extend("force", {
    bufhidden = "hide",
    buflisted = false,
    buftype = "nofile",
    modifiable = false,
    readonly = true,
    swapfile = false,
  }, defaults(options.buf_options, {}))
  _.set_buf_options(self.bufnr, self.buf_options)

  self.win_options = vim.tbl_extend("force", {
    foldcolumn = "0",
    foldmethod = "manual",
    wrap = false,
  }, defaults(options.win_options, {}))
  _.set_win_options(self.winid, self.win_options)

  self.ns_id = is_type("string", options.ns) and vim.api.nvim_create_namespace(options.ns) or options.ns

  self.get_node_id = defaults(options.get_node_id, default_get_node_id)
  self.prepare_node = defaults(options.prepare_node, default_prepare_node)

  self._content = { lines = {}, node_id_by_linenr = {} }

  self.nodes = { by_id = {}, root_ids = {} }

  self:add_nodes(defaults(options.nodes, {}))

  return self
end

---@param node_id? string
---@return table NuiTreeNode
function Tree:get_node(node_id)
  local id = node_id
  if not id then
    local linenr = vim.api.nvim_win_get_cursor(self.winid)[1]
    id = self._content.node_id_by_linenr[linenr]
  end
  return self.nodes.by_id[id]
end

function Tree:add_nodes(nodes, parent_id)
  local parent_node = parent_id and self.nodes.by_id[parent_id] or nil
  if parent_id and not parent_node then
    error("invalid parent_id " .. parent_id)
  end

  local new_nodes = initialize_nodes(nodes, parent_node, self.get_node_id)

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

---@param node table NuiTreeNode
---@param parent_id? string parent node's id
function Tree:add_node(node, parent_id)
  self:add_nodes({ node }, parent_id)
end

function Tree:remove_node(node_id)
  local node = self.nodes.by_id[node_id]
  self.nodes.by_id[node_id] = nil
  local parent_id = node._parent_id
  if parent_id then
    local parent_node = self.nodes.by_id[parent_id]
    parent_node._child_ids = vim.tbl_filter(function(id)
      return id ~= node_id
    end, parent_node._child_ids)
  end
  return node
end

function Tree:_prepare_content()
  self._content.lines = {}
  self._content.node_id_by_linenr = {}

  local current_linenr = 1

  local function prepare(node_id)
    local node = self.nodes.by_id[node_id]
    if not node then
      return
    end

    local line = self.prepare_node(node)
    self._content.lines[current_linenr] = line
    self._content.node_id_by_linenr[current_linenr] = node:get_id()
    current_linenr = current_linenr + 1

    if not node:has_children() or not node:is_expanded() then
      return
    end

    for _, child_node_id in ipairs(node._child_ids) do
      prepare(child_node_id)
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
      line:highlight(self.bufnr, i, self.ns_id)
    end
  end

  _.set_buf_options(self.bufnr, { modifiable = false, readonly = true })
end

local TreeClass = setmetatable({
  __index = Tree,
}, {
  __call = init,
  __index = Tree,
})

return TreeClass
