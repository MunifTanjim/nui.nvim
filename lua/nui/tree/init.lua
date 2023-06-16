local Object = require("nui.object")
local _ = require("nui.utils")._
local defaults = require("nui.utils").defaults
local tree_util = require("nui.tree.util")

-- returns id of the first window that contains the buffer
---@param bufnr number
---@return number winid
local function get_winid(bufnr)
  return vim.fn.win_findbuf(bufnr)[1]
end

---@param get_tree fun(): NuiTree
---@param nodes NuiTree.Node[]
---@param parent_node? NuiTree.Node
---@param get_node_id nui_tree_get_node_id
---@return { by_id: table<string, NuiTree.Node>, root_ids: string[] }
local function initialize_nodes(get_tree, nodes, parent_node, get_node_id)
  local start_depth = parent_node and parent_node:get_depth() + 1 or 1

  ---@type table<string, NuiTree.Node>
  local by_id = {}
  ---@type string[]
  local root_ids = {}

  ---@param node NuiTree.Node
  ---@param depth number
  local function initialize(node, depth)
    node.get_tree = get_tree
    node._depth = depth
    node._height = 0
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

    local prev_child_node
    for _, child_node in ipairs(node.__children) do
      child_node._parent_id = node_id
      initialize(child_node, depth + 1)
      table.insert(node._child_ids, child_node:get_id())

      child_node._prev = prev_child_node and prev_child_node:get_id()
      if prev_child_node then
        prev_child_node._next = child_node:get_id()
      end

      prev_child_node = child_node
    end

    node.__children = nil
  end

  local prev_node
  for _, node in ipairs(nodes) do
    node._parent_id = parent_node and parent_node:get_id() or nil
    initialize(node, start_depth)
    node._prev = prev_node and prev_node:get_id()
    if prev_node then
      prev_node._next = node:get_id()
    end
    prev_node = node
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
---@field _next? string
---@field _prev? string
---@field get_tree fun(): NuiTree
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
  local items = self._child_ids or self.__children
  return items and #items > 0 or false
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
  if (self._child_ids or self.__children) and not self:is_expanded() then
    self._is_expanded = true
    if self.get_tree then
      local tree = self:get_tree()
      tree:_relink_node(self)
    end
    return true
  end
  return false
end

---@return boolean is_updated
function TreeNode:collapse()
  if self:is_expanded() then
    self._is_expanded = false
    if self.get_tree then
      local tree = self:get_tree()
      tree:_relink_node(self)
    end
    return true
  end
  return false
end

--luacheck: push no max line length

---@alias nui_tree_get_node_id fun(node: NuiTree.Node): string
---@alias nui_tree_prepare_node fun(node: NuiTree.Node, parent_node?: NuiTree.Node): nil | string | string[] | NuiLine | NuiLine[]

--luacheck: pop

---@class nui_tree_internal
---@field buf_options table<string, any>
---@field get_node_id nui_tree_get_node_id
---@field linenr { [1]?: integer, [2]?: integer }
---@field linenr_by_node_id table<string, { [1]: integer, [2]: integer }>
---@field node_id_by_linenr table<integer, string>
---@field prepare_node nui_tree_prepare_node
---@field win_options table<string, any> # deprecated
---@field head? string
---@field tail? string
---@field get_tree fun(): NuiTree
---@field pending_changes { [1]: integer, [2]: integer, [3]: NuiTree.Node, [4]?: NuiTree.Node }[]

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

    linenr = {},
    pending_changes = {},
  }

  self._.get_tree = function()
    return self
  end

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
    _height = 0,
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

---@param node NuiTree.Node
---@param head_id? string
---@param head_linenr? integer
function Tree:_get_node_linenr(node, head_id, head_linenr)
  local linenr_start = self._.linenr[1]
  local by_id = self.nodes.by_id
  local linenr = head_linenr or linenr_start or 1
  local head = by_id[head_id or self._head]
  while head and head ~= node do
    linenr = linenr + head._height
    head = by_id[head._next]
  end
  return linenr, linenr + node._height - 1
end

---@param linenr integer
---@return nil|NuiTree.Node node
---@return nil|integer linenr_start
---@return nil|integer linenr_end
function Tree:_get_node_by_linenr(linenr)
  local node_linenr = self._.linenr[1]
  if node_linenr > linenr then
    return
  end

  local by_id = self.nodes.by_id

  local node = by_id[self._head]
  local node_height_below = node and node._height
  while node and node_linenr < linenr do
    node_linenr = node_linenr + 1
    node_height_below = node_height_below - 1
    if node_height_below == 0 then
      node = by_id[node._next]
      node_height_below = node and node._height
    end
  end

  if not node then
    return
  end

  return node, linenr + node_height_below - node._height, linenr + node_height_below - 1
end

---@param node_id_or_linenr? string | integer
---@return NuiTree.Node|nil node
---@return nil|integer linenr
---@return nil|integer linenr
function Tree:get_node(node_id_or_linenr)
  if type(node_id_or_linenr) == "string" then
    local node = self.nodes.by_id[node_id_or_linenr]
    if not node then
      return
    end
    return node, self:_get_node_linenr(node)
  end

  local winid = get_winid(self.bufnr)
  local linenr = node_id_or_linenr or vim.api.nvim_win_get_cursor(winid)[1]

  return self:_get_node_by_linenr(linenr)
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
  local new_nodes = initialize_nodes(self._.get_tree, nodes, parent_node, self._.get_node_id)

  self.nodes.by_id = vim.tbl_extend("force", self.nodes.by_id, new_nodes.by_id)
  local by_id = self.nodes.by_id

  local node_ids = self.nodes.root_ids
  if parent_node then
    if not parent_node._child_ids then
      parent_node._child_ids = {}
    end

    node_ids = parent_node._child_ids --[=[@as string[]]=]
    self:_relink_node(parent_node)
  end

  local old_last_idx = #node_ids

  for idx, id in ipairs(new_nodes.root_ids) do
    node_ids[old_last_idx + idx] = id
  end

  local old_last_sibling = by_id[node_ids[old_last_idx]]
  local first_new_sibling = by_id[node_ids[old_last_idx + 1]]
  if first_new_sibling then
    first_new_sibling._prev = old_last_sibling and old_last_sibling:get_id()
    if old_last_sibling then
      old_last_sibling._next = first_new_sibling:get_id()
    end
  end
end

---@param nodes NuiTree.Node[]
---@param parent_id? string parent node's id
function Tree:set_nodes(nodes, parent_id)
  if not parent_id then
    self.nodes = { by_id = {}, root_ids = {} }
    self:_add_nodes(nodes)
    self:_link()
    self:_queue_pending_change(self._.linenr[1], self._.linenr[2], self.nodes.by_id[self._head])
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

---@param node NuiTree.Node
---@return nil|NuiTree.Node
function Tree:_get_next_node(node)
  local by_id = self.nodes.by_id

  local next_node = nil

  while node and not next_node do
    local parent = by_id[node:get_parent_id()]
    local sibling_ids = parent and parent:get_child_ids() or self.nodes.root_ids
    local node_id_idx = _.find_index(sibling_ids, node:get_id()) or -1
    next_node = by_id[sibling_ids[node_id_idx + 1]]
    node = parent
  end

  return next_node
end

---@param node NuiTree.Node
---@return integer linenr_start
---@return integer linenr_end
---@return NuiTree.Node? next_node
function Tree:_get_node_boundary(node)
  local linenr_start, linenr_end = self:_get_node_linenr(node)
  local next_node = self:_get_next_node(node)
  if next_node then
    local next_node_linenr_start = self:_get_node_linenr(next_node, node._next, linenr_end + 1)
    return linenr_start, next_node_linenr_start - 1, next_node
  end
  return linenr_start, self._.linenr[2]
end

---@param linenr_start integer
---@param linenr_end integer
---@param node NuiTree.Node
---@param stop_node? NuiTree.Node
function Tree:_queue_pending_change(linenr_start, linenr_end, node, stop_node)
  if not self._.linenr[1] then
    return
  end

  -- detect overlaping pending change
  for _, change in ipairs(self._.pending_changes) do
    if change[1] <= linenr_start and linenr_end <= change[2] then
      return
    end
  end

  table.insert(self._.pending_changes, { linenr_start, linenr_end, node, stop_node })
end

---@param node NuiTree.Node
---@return nil|NuiTree.Node first_inner_node
---@return nil|NuiTree.Node last_inner_node
function Tree:_get_inner_boundary_nodes(node)
  if not node:has_children() or not node:is_expanded() then
    return
  end

  local by_id = self.nodes.by_id
  local child_ids = node:get_child_ids()
  local first_node = by_id[child_ids[1]]
  local last_node = by_id[child_ids[#child_ids]]
  while last_node and last_node:has_children() and last_node:is_expanded() do
    child_ids = last_node:get_child_ids()
    last_node = by_id[child_ids[#child_ids]]
  end
  return first_node, last_node
end

---@param node NuiTree.Node
function Tree:_relink_node(node)
  local linenr_start, linenr_end, next_node = self:_get_node_boundary(node)

  if node:has_children() and node:is_expanded() then
    local first_node, last_node = self:_get_inner_boundary_nodes(node)
    if first_node then
      node._next = first_node:get_id()
      first_node._prev = node:get_id()
    end
    if last_node then
      if next_node then
        last_node._next = next_node:get_id()
        next_node._prev = last_node:get_id()
      else
        last_node._next = nil
      end
    end
  else
    if next_node then
      node._next = next_node:get_id()
      next_node._prev = node:get_id()
    else
      node._next = nil
    end
  end

  self:_queue_pending_change(linenr_start, linenr_end, node, next_node)
end

---@param node NuiTree.Node
---@return nil|(string|NuiLine)[]
function Tree:_prepare_node(node)
  local parent_node = self.nodes.by_id[node._parent_id]

  local node_lines = self._.prepare_node(node, parent_node)

  if not node_lines then
    node._height = 0
    return
  end

  if type(node_lines) ~= "table" or node_lines.content then
    node._height = 1
    return { node_lines }
  end

  node._height = #node_lines
  return node_lines
end

function Tree:_link()
  local by_id = self.nodes.by_id

  local prev_node = nil

  local function link(node_id)
    local node = by_id[node_id]

    node._prev = prev_node
    if prev_node then
      node._prev = node._prev:get_id()
      prev_node._next = node:get_id()
    end
    prev_node = node

    local child_ids = node._child_ids
    if child_ids and node._is_expanded then
      for child_id_idx = 1, #child_ids do
        link(child_ids[child_id_idx])
      end
    end
  end

  local root_ids = self.nodes.root_ids
  for node_id_idx = 1, #root_ids do
    link(root_ids[node_id_idx])
  end

  self._head = root_ids[1]
  self._tail = prev_node
end

---@param linenr_start? number start line number (1-indexed)
function Tree:render(linenr_start)
  linenr_start = math.max(1, linenr_start or self._.linenr[1] or 1)

  local by_id = self.nodes.by_id
  local linenr = self._.linenr
  local pending_changes = self._.pending_changes

  local prev_linenr = { linenr[1], linenr[2] }

  if not prev_linenr[1] then
    self:_link()

    linenr[1] = linenr_start
    linenr[2] = linenr_start
  end

  if not pending_changes[1] then
    pending_changes[1] = {
      linenr[1],
      linenr[2],
      by_id[self._head],
      nil,
    }
  end

  _.set_buf_options(self.bufnr, { modifiable = true, readonly = false })

  local changes_len = #pending_changes

  for change_idx = 1, changes_len do
    local change = pending_changes[change_idx]

    ---@type (string|NuiLine)[]
    local lines = {}
    local line_idx = 0

    local node, stop_node = change[3], change[4]
    while node and node ~= stop_node do
      local node_lines = self:_prepare_node(node)
      for node_line_idx = 1, node._height do
        ---@cast node_lines -nil
        line_idx = line_idx + 1
        lines[line_idx] = node_lines[node_line_idx]
      end
      node = by_id[node._next]
    end

    local c_linenr_start, c_linenr_end = change[1], change[2]

    linenr[2] = linenr[2] + line_idx - (c_linenr_end - c_linenr_start) - 1

    _.clear_namespace(self.bufnr, self.ns_id, c_linenr_start, c_linenr_end)

    _.render_lines(lines, self.bufnr, self.ns_id, c_linenr_start, c_linenr_end)

    pending_changes[change_idx] = nil
  end

  local linenr_shift = linenr_start - linenr[1]
  if 0 < linenr_shift then
    -- shift downwards
    local lines = {}
    for i = 1, linenr_shift do
      lines[i] = ""
    end
    _.render_lines(lines, self.bufnr, self.ns_id, linenr[1], linenr[1] - 1)
  elseif linenr_shift < 0 then
    -- shift upwards
    _.render_lines({}, self.bufnr, self.ns_id, linenr_start, linenr[1] - 1)
  end
  linenr[1] = linenr_start
  linenr[2] = linenr[2] + linenr_shift

  _.set_buf_options(self.bufnr, { modifiable = false, readonly = true })
end

---@alias NuiTree.constructor fun(options: nui_tree_options): NuiTree
---@type NuiTree|NuiTree.constructor
local NuiTree = Tree

return NuiTree
