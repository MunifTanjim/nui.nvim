# NuiTree

NuiTree can render tree-like structured content on the buffer.

```lua
local NuiTree = require("nui.tree")

local tree = NuiTree({
  winid = winid,
  nodes = {
    NuiTree.Node({ text = "a" }),
    NuiTree.Node({ text = "b" }, {
      NuiTree.Node({ text = "b-1" }),
      NuiTree.Node({ text = "b-2" }),
    }),
  },
})

tree:render()
```

## Options

### `winid`

**Type:** `number`

Id of the window where the tree will be rendered.

---

### `ns_id`

**Type:** `number` or `string`

Namespace id (`number`) or name (`string`).

---

### `nodes`

**Type:** `table`

List of [`NuiTree.Node`](#nuitreenode) objects.

---

### `get_node_id(node)`

**Type:** `function`

If provided, this function is used for generating node's id.

The return value should be a unique `string`.

**Example**

```lua
get_node_id = function(node)
  if node.id then
    return "-" .. node.id
  end

  if node.text then
    return string.format("%s-%s-%s", node:get_parent_id() or "", node:get_depth(), node.text)
  end

  return "-" .. math.random()
end,
```

---

### `prepare_node(node)`

**Type:** `function`

If provided, this function is used for preparing each node line.

The return value should be a `NuiLine` object or `string`.

**Example**

```lua
prepare_node = function(node)
  local line = NuiLine()

  line:append(string.rep("  ", node:get_depth() - 1))

  if node:has_children() then
    line:append(node:is_expanded() and " " or " ")
  else
    line:append("  ")
  end

  line:append(node.text)

  return line
end,
```

---

### `buf_options`

**Type:** `table`

Contains all buffer related options (check `:h options | /local to buffer`).

**Examples**

```lua
buf_options = {
  bufhidden = "hide",
  buflisted = false,
  buftype = "nofile",
  swapfile = false,
},
```

---

### `win_options`

**Type:** `table`

Contains all window related options (check `:h options | /local to window`).

**Examples**

```lua
win_options = {
  foldcolumn = "0",
  foldmethod = "manual",
  wrap = false,
},
```

## Methods

### `tree:get_node(node_id?)`

Returns `NuiTree.Node` object.

**Parameters**

| Name      | Type              | Description |
| --------- | ----------------- | ----------- |
| `node_id` | `string` or `nil` | node's id   |

If `node_id` is `nil`, the current node under cursor is returned.

### `tree:add_node(node, parent_id?)`

Adds a node to the tree.

| Name        | Type              | Description      |
| ----------- | ----------------- | ---------------- |
| `node`      | `NuiTree.Node`    | node             |
| `parent_id` | `string` or `nil` | parent node's id |

If `parent_id` is present, node is added under that parent,
Otherwise node is added to the tree root.

### `tree:remove_node(node)`

Removes a node from the tree.

Returns the removed node.

| Name      | Type     | Description |
| --------- | -------- | ----------- |
| `node_id` | `string` | node's id   |

### `tree:set_nodes(nodes, parent_id?)`

Adds a node to the tree.

| Name        | Type              | Description      |
| ----------- | ----------------- | ---------------- |
| `nodes`     | `NuiTree.Node[]`  | list of nodes    |
| `parent_id` | `string` or `nil` | parent node's id |

If `parent_id` is present, nodes are set as parent node's children,
otherwise nodes are set at tree root.

### `tree:render()`

Renders the tree on buffer.

## NuiTree.Node

`NuiTree.Node` is used to create a node object for `NuiTree`.

```lua
local NuiTree = require("nui.tree")

local node = NuiTree.Node({ text = "b" }, {
  NuiTree.Node({ text = "b-1" }),
  NuiTree.Node({ text = "b-2" }),
})
```

### Parameters

_Signature:_ `NuiTree.Node(data, children)`

#### `data`

**Type:** `table`

Data for the node. Can contain anything. The default `get_node_id`
and `prepare_node` functions uses the `id` and `text` keys.

**Example**

```lua
{
  id = "/usr/local/bin/lua",
  text = "lua"
}
```

If you don't want to provide those two values, you should consider
providing your own `get_node_id` and `prepare_node` functions.

#### `children`

**Type:** `table`

List of `NuiTree.Node` objects.

### Methods

#### `node:get_id()`

Returns node's id.

#### `node:get_depth()`

Returns node's depth.

#### `node:get_parent_id()`

Returns parent node's id.

#### `node:has_children()`

Checks if node has children.

#### `node:is_expanded()`

Checks if node is expanded.

#### `node:expand()`

Expands node.

#### `node:collapse()`

Collapses node.
