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

---@param tree NuiTree
---@param nodes NuiTree.Node[]
---@param parent_node? NuiTree.Node
---@param get_node_id nui_tree_get_node_id
---@return { by_id: table<string, NuiTree.Node>, root_ids: string[] }
local function initialize_nodes(tree, nodes, parent_node, get_node_id)
  local start_depth = parent_node and parent_node:get_depth() + 1 or 1

  ---@type table<string, NuiTree.Node>
  local by_id = {}
  ---@type string[]
  local root_ids = {}

  ---@param node NuiTree.Node
  ---@param depth number
  local function initialize(node, depth)
    node._tree = tree
    node._depth = depth
    node._height = 0
    node._id = get_node_id(node)
    node._initialized = true

    local node_id = node:get_id()

    if by_id[node_id] then
      error("duplicate node id " .. node_id)
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
---@field _tree? NuiTree
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
    if self._tree then
      self._tree:_refresh_node(self)
    end
    return true
  end
  return false
end

---@return boolean is_updated
function TreeNode:collapse()
  if self:is_expanded() then
    self._is_expanded = false
    if self._tree then
      self._tree:_refresh_node(self)
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
---@field linenr_by_node_id? table<string, { [1]: integer, [2]: integer }> # memoized, nil when invalidated
---@field node_id_by_linenr? table<integer, string> # memoized, nil when invalidated
---@field linenr_cache_misses integer
---@field needs_full_render? boolean
---@field prepare_node nui_tree_prepare_node
---@field win_options table<string, any> # deprecated
---@field pending_changes { [1]: integer, [2]: integer, [3]?: NuiTree.Node, [4]?: NuiTree.Node }[]

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
---@field private _head? string # id of the first visible node
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
    linenr_cache_misses = 0,
    pending_changes = {},
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
  local by_id = self.nodes.by_id

  -- fast path: when the memoized cache is warm it holds the answer in O(1),
  -- avoiding the O(distance-from-head) walk below. Only usable for a full walk
  -- from the head (no explicit start point), which is what every caller that
  -- matters for performance uses. The cache is invalidated on every layout
  -- change, so a present entry is always accurate.
  if not head_id and self._.linenr_by_node_id then
    local range = self._.linenr_by_node_id[node:get_id()]
    if range then
      return range[1], range[2]
    end
  end

  local linenr_start = self._.linenr[1]
  local linenr = head_linenr or linenr_start or 1
  local head = by_id[head_id or self._head]
  while head and head ~= node do
    linenr = linenr + head._height
    head = by_id[head._next]
  end
  return linenr, linenr + node._height - 1
end

---@param node NuiTree.Node
---@return NuiTree.Node last_visible_node
function Tree:_get_last_visible_node(node)
  local by_id = self.nodes.by_id
  while node:has_children() and node:is_expanded() do
    local child_ids = node:get_child_ids()
    node = by_id[child_ids[#child_ids]]
  end
  return node
end

---@param node NuiTree.Node
---@return boolean
function Tree:_is_node_visible(node)
  local by_id = self.nodes.by_id
  local parent_id = node:get_parent_id()
  while parent_id do
    local parent = by_id[parent_id]
    if not parent or not parent:is_expanded() then
      return false
    end
    parent_id = parent:get_parent_id()
  end
  return true
end

-- Locate the node at an absolute line number with a single walk from the head.
-- Used for one-off lookups when the memoized tables are not (yet) built.
---@param linenr integer
---@return nil|NuiTree.Node node
---@return nil|integer linenr_start
---@return nil|integer linenr_end
function Tree:_get_node_by_linenr(linenr)
  local node_linenr = self._.linenr[1]
  if not node_linenr or node_linenr > linenr then
    return
  end

  local by_id = self.nodes.by_id

  -- Walk the visible chain node-by-node, skipping nodes that render nothing
  -- (`_height == 0`), until we reach the node whose range covers `linenr`.
  local node = by_id[self._head]
  while node do
    local height = node._height or 0
    if height > 0 then
      local linenr_end = node_linenr + height - 1
      if linenr <= linenr_end then
        return node, node_linenr, linenr_end
      end
      node_linenr = node_linenr + height
    end
    node = by_id[node._next]
  end
end

-- Drop the memoized line-number lookup tables. Called whenever the visible
-- layout changes; they are rebuilt lazily once lookups make it worthwhile.
function Tree:_invalidate_linenr_cache()
  self._.linenr_by_node_id = nil
  self._.node_id_by_linenr = nil
  self._.linenr_cache_misses = 0
end

-- Build the id<->linenr lookup tables with a single O(visible) walk, memoized
-- until the next layout change. This keeps get_node() O(1) for the common
-- "render once, then many lookups" pattern without paying per-mutation cost.
function Tree:_ensure_linenr_cache()
  if self._.linenr_by_node_id then
    return
  end

  local by_id = self.nodes.by_id
  local by_node_id = {}
  local by_linenr = {}

  local linenr = self._.linenr[1]
  local node = linenr and by_id[self._head] or nil
  while node do
    local height = node._height or 0
    if height > 0 then
      local id = node:get_id()
      by_node_id[id] = { linenr, linenr + height - 1 }
      for l = linenr, linenr + height - 1 do
        by_linenr[l] = id
      end
      linenr = linenr + height
    end
    node = by_id[node._next]
  end

  self._.linenr_by_node_id = by_node_id
  self._.node_id_by_linenr = by_linenr
end

---@param node_id_or_linenr? string | integer
---@return NuiTree.Node|nil node
---@return nil|integer linenr
---@return nil|integer linenr
function Tree:get_node(node_id_or_linenr)
  local by_id_lookup = is_type("string", node_id_or_linenr)

  if not self._.linenr[1] then
    -- nothing has been rendered yet, so no line numbers exist
    if by_id_lookup then
      return self.nodes.by_id[node_id_or_linenr]
    end
    return
  end

  -- Promote to the memoized tables once lookups repeat against the same layout;
  -- a lone lookup after a mutation is cheaper via a single direct walk than by
  -- rebuilding the whole table only to have the next mutation discard it.
  if not self._.linenr_by_node_id then
    self._.linenr_cache_misses = self._.linenr_cache_misses + 1
    if self._.linenr_cache_misses >= 2 then
      self:_ensure_linenr_cache()
    end
  end

  if by_id_lookup then
    local node = self.nodes.by_id[node_id_or_linenr]
    if not node then
      return
    end
    if self._.linenr_by_node_id then
      local range = self._.linenr_by_node_id[node_id_or_linenr]
      if not range then
        return node -- node exists but is not currently visible
      end
      return node, range[1], range[2]
    end
    -- cold path: a single direct walk. A hidden node (collapsed ancestor) or a
    -- node that renders nothing (height 0) occupies no line, so it has no line
    -- range to report; this matches the memoized path, which omits such nodes.
    if node._height == 0 or not self:_is_node_visible(node) then
      return node
    end
    return node, self:_get_node_linenr(node)
  end

  local linenr = node_id_or_linenr or vim.api.nvim_win_get_cursor(get_winid(self.bufnr))[1]
  if self._.linenr_by_node_id then
    local node_id = self._.node_id_by_linenr[linenr]
    if not node_id then
      return
    end
    local range = self._.linenr_by_node_id[node_id]
    return self.nodes.by_id[node_id], range[1], range[2]
  end

  -- cold path: a single direct walk
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

-- Remove a node subtree from the id map and detach it from the tree so the nodes
-- can be garbage collected and are not mistaken for live nodes (e.g. a stale
-- reference calling node:expand() dispatching to a tree it no longer belongs to).
---@param tree NuiTree
---@param node_id string
---@return NuiTree.Node
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
  node._tree = nil
  node._prev = nil
  node._next = nil
  return node
end

-- Merge freshly initialized nodes into the tree's id map in place, so a mutation
-- stays O(added) instead of copying the whole map (as vim.tbl_extend would).
---@param by_id table<string, NuiTree.Node>
---@param new_by_id table<string, NuiTree.Node>
local function merge_by_id(by_id, new_by_id)
  for id, node in pairs(new_by_id) do
    by_id[id] = node
  end
end

---@param nodes NuiTree.Node[]
---@param parent_node? NuiTree.Node
function Tree:_add_nodes(nodes, parent_node)
  -- the cache is intentionally kept until the layout actually changes, so the
  -- boundary computation below (via _get_node_linenr) can still use it. The
  -- paths that do change the visible layout invalidate it: the parent-add path
  -- through _queue_pending_change, and the root-append branch explicitly. Adding
  -- under a collapsed/hidden parent changes nothing visible, so it stays valid.
  local new_nodes = initialize_nodes(self, nodes, parent_node, self._.get_node_id)

  local by_id = self.nodes.by_id
  merge_by_id(by_id, new_nodes.by_id)

  local node_ids = self.nodes.root_ids
  if parent_node then
    if not parent_node._child_ids then
      parent_node._child_ids = {}
    end

    node_ids = parent_node._child_ids --[=[@as string[]]=]
  end

  local old_last_idx = #node_ids
  local old_last_sibling = by_id[node_ids[old_last_idx]]

  for idx, id in ipairs(new_nodes.root_ids) do
    node_ids[old_last_idx + idx] = id
  end

  local first_new_sibling = by_id[new_nodes.root_ids[1]]
  if not first_new_sibling then
    return
  end

  -- link the previously-last visible descendant to the first new sibling
  local function link_old_last_to_new()
    local old_last_visible = self:_get_last_visible_node(old_last_sibling)
    old_last_visible._next = first_new_sibling:get_id()
    first_new_sibling._prev = old_last_visible:get_id()
  end

  if parent_node and (not parent_node:is_expanded() or not self:_is_node_visible(parent_node)) then
    -- parent's subtree is not on screen: only keep the sibling chain consistent so that
    -- the new nodes appear correctly whenever the parent becomes visible
    if old_last_sibling then
      link_old_last_to_new()
    end
    return
  end

  if parent_node then
    -- relink the parent so it connects to its (now updated) children and successor;
    -- _relink_subtree already chains the new siblings into the visible list, so no
    -- separate boundary link is needed here
    self:_relink_node(parent_node)
    return
  end

  if not self._head then
    self._head = self.nodes.root_ids[1]
  end
  -- a root-level append extends the visible layout at the end, so the memoized
  -- line numbers are now stale
  self:_invalidate_linenr_cache()
  -- a root-level append is not covered by any queued pending change; force a full
  -- re-render so it is not dropped when another change is queued in the same render
  if self._.linenr[1] then
    self._.needs_full_render = true
  end

  -- chain each appended root's whole visible subtree into the list. initialize_nodes
  -- only links the sibling chain, so an already-expanded appended root would otherwise
  -- have its descendants disconnected (and dropped from the render).
  local prev = old_last_sibling and self:_get_last_visible_node(old_last_sibling) or nil
  for _, id in ipairs(new_nodes.root_ids) do
    local root = by_id[id]
    if prev then
      prev._next = root:get_id()
      root._prev = prev:get_id()
    else
      root._prev = nil
    end
    prev = self:_relink_subtree(root)
  end
  if prev then
    prev._next = nil
  end
end

---@param nodes NuiTree.Node[]
---@param parent_id? string parent node's id
function Tree:set_nodes(nodes, parent_id)
  if not parent_id then
    -- detach the old nodes before dropping them so a stale reference cannot poke
    -- the tree (mirrors remove_node); self.nodes is nil on the first call from init()
    if self.nodes then
      for _, node_id in ipairs(self.nodes.root_ids) do
        remove_node(self, node_id)
      end
    end
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

  -- capture the region occupied by the parent's current subtree before it is replaced,
  -- since removing the old children makes it impossible to measure afterwards
  local should_relink = self._.linenr[1] and self._head and self:_is_node_visible(parent_node)
  local linenr_start, linenr_end, next_node
  if should_relink then
    linenr_start, linenr_end, next_node = self:_get_node_boundary(parent_node)
  end

  if parent_node._child_ids then
    -- detach the old children (recursively) before dropping them so a stale
    -- reference cannot poke the tree (mirrors remove_node)
    for _, node_id in ipairs(parent_node._child_ids) do
      remove_node(self, node_id)
    end

    parent_node._child_ids = nil
  end

  local new_nodes = initialize_nodes(self, nodes, parent_node, self._.get_node_id)
  merge_by_id(self.nodes.by_id, new_nodes.by_id)
  parent_node._child_ids = new_nodes.root_ids

  if should_relink then
    self:_relink_node_to(parent_node, next_node)
    self:_queue_pending_change(linenr_start, linenr_end, parent_node, next_node)
  end
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

---@param node_id string
---@return NuiTree.Node
function Tree:remove_node(node_id)
  local node = self.nodes.by_id[node_id]
  if not node then
    error("invalid node_id " .. node_id)
  end

  local should_relink = self._.linenr[1] and self._head and self:_is_node_visible(node)
  local linenr_start, linenr_end, next_node
  if should_relink then
    linenr_start, linenr_end, next_node = self:_get_node_boundary(node)
  end
  local prev_id = node._prev
  -- capture before remove_node() detaches the node's chain/parent references
  local parent_id = node._parent_id

  remove_node(self, node_id)

  -- drop the id from its sibling list in place (order preserved, no allocation)
  local sibling_ids = parent_id and self.nodes.by_id[parent_id]._child_ids or self.nodes.root_ids
  local sibling_idx = _.find_index(sibling_ids, node_id)
  if sibling_idx then
    table.remove(sibling_ids, sibling_idx)
  end

  if should_relink then
    local next_id = next_node and next_node:get_id() or nil
    local prev_node = prev_id and self.nodes.by_id[prev_id]
    if next_node then
      next_node._prev = prev_id
    end
    if prev_node then
      prev_node._next = next_id
    end
    if self._head == node_id then
      self._head = next_id
    end
    self:_queue_pending_change(linenr_start, linenr_end, next_node, next_node)
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
---@param node? NuiTree.Node
---@param stop_node? NuiTree.Node
function Tree:_queue_pending_change(linenr_start, linenr_end, node, stop_node)
  if not self._.linenr[1] then
    return
  end

  -- the layout is about to change, so the memoized line numbers are stale
  self:_invalidate_linenr_cache()

  -- detect overlaping pending change
  for _, change in ipairs(self._.pending_changes) do
    if change[1] <= linenr_start and linenr_end <= change[2] then
      return
    end
  end

  table.insert(self._.pending_changes, { linenr_start, linenr_end, node, stop_node })
end

-- Relink the visible chain within node's subtree (node included), following the
-- current child order and expansion state. Returns the last visible node of the
-- subtree. Rebuilding the whole subtree (rather than just its boundary) keeps the
-- chain correct even when a descendant's expansion changed while it was hidden.
-- Does not touch node._prev or the link leaving the subtree.
---@param node NuiTree.Node
---@return NuiTree.Node last_visible_node
function Tree:_relink_subtree(node)
  if not (node:has_children() and node:is_expanded()) then
    return node
  end

  local by_id = self.nodes.by_id
  local prev = node
  for _, child_id in ipairs(node:get_child_ids()) do
    local child = by_id[child_id]
    if child then
      prev._next = child:get_id()
      child._prev = prev:get_id()
      prev = self:_relink_subtree(child)
    end
  end
  return prev
end

-- Relink node's whole visible subtree and connect its last visible node to
-- next_node (the node that follows the subtree in the visible list).
---@param node NuiTree.Node
---@param next_node? NuiTree.Node
function Tree:_relink_node_to(node, next_node)
  local last_node = self:_relink_subtree(node)
  if next_node then
    last_node._next = next_node:get_id()
    next_node._prev = last_node:get_id()
  else
    last_node._next = nil
  end
end

---@param node NuiTree.Node
function Tree:_relink_node(node)
  local linenr_start, linenr_end, next_node = self:_get_node_boundary(node)
  self:_relink_node_to(node, next_node)
  self:_queue_pending_change(linenr_start, linenr_end, node, next_node)
end

-- Handle a node's expand/collapse: relink incrementally when the node is on
-- screen, otherwise leave the visible list untouched (the ancestor's own relink
-- rebuilds the subtree when it becomes visible again).
---@param node NuiTree.Node
function Tree:_refresh_node(node)
  if not self._.linenr[1] then
    return -- not rendered yet; the first render links everything
  end
  if not self:_is_node_visible(node) then
    return -- hidden; nothing on screen changes
  end
  self:_relink_node(node)
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

  local head_node = nil
  local prev_node = nil

  local function link(node_id)
    local node = by_id[node_id]
    -- an id can be missing from by_id in an unexpected/corrupted state; skip it
    -- instead of crashing so the rest of the tree still renders
    if not node then
      return
    end

    node._prev = prev_node and prev_node:get_id() or nil
    if prev_node then
      prev_node._next = node:get_id()
    end
    node._next = nil
    if not head_node then
      head_node = node
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

  self._head = head_node and head_node:get_id() or nil
end

---@param linenr_start? number start line number (1-indexed)
function Tree:render(linenr_start)
  linenr_start = math.max(1, linenr_start or self._.linenr[1] or 1)

  -- rendering reflows the buffer, so any memoized line numbers are stale
  self:_invalidate_linenr_cache()

  local by_id = self.nodes.by_id
  local linenr = self._.linenr
  local pending_changes = self._.pending_changes

  local was_rendered = linenr[1] ~= nil

  if not was_rendered then
    self:_link()

    linenr[1] = linenr_start
    linenr[2] = linenr_start
  end

  -- With a single queued change we can re-render just that region. With none, with
  -- multiple changes (whose absolute line numbers would need rebasing against each other),
  -- or with a change not captured by pending_changes (a root-level append), fall back to a
  -- single full re-render from the head over the current extent. The linked list is already
  -- up to date, so a full walk always produces the correct buffer.
  if not pending_changes[1] or pending_changes[2] or self._.needs_full_render then
    self._.pending_changes = {
      {
        linenr[1],
        linenr[2],
        by_id[self._head],
        nil,
      },
    }
    pending_changes = self._.pending_changes
  end
  self._.needs_full_render = nil

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
