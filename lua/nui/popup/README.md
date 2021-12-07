# Popup

Popup is an abstraction layer on top of window.

Creates a new popup object (but does not mount it immediately).

```lua
local Popup = require("nui.popup")

local popup = Popup({
  position = "50%",
  size = {
    width = 80,
    height = 40,
  },
  enter = true,
  focusable = true,
  zindex = 50,
  relative = "editor",
  border = {
    highlight = "FloatBorder",
    padding = {
      top = 2,
      bottom = 2,
      left = 3,
      right = 3,
    },
    style = "rounded",
    text = {
      top = " I am top title ",
      top_align = "center",
      bottom = "I am bottom title",
      bottom_align = "left",
    },
  },
  buf_options = {
    modifiable = true,
    readonly = false,
  },
  win_options = {
    winblend = 10,
    winhighlight = "Normal:Normal",
  },
})
```

You can manipulate the assocciated buffer and window using the
`split.bufnr` and `split.winid` properties.

## Options

### `border`

**Type:** `table`

Contains all border related options.

#### `border.padding`

**Type:** `table`

Controls the popup padding.

**Examples**

It can be a list (`table`) with number of cells for top, right, bottom and left.
The order behaves like [CSS](https://developer.mozilla.org/en-US/docs/Web/CSS) padding.

```lua
border = {
  -- `1` for top/bottom and `2` for left/right
  padding = { 1, 2 },
},
```

You can also use a map (`table`) to set padding at specific side:

```lua
border = {
  -- `1` for top, `2` for left, `0` for other sides
  padding = {
    top = 1,
    left = 2,
  },
},
```

#### `border.highlight`

**Type:** `string`

Highlight group name for the border characters.

**Examples**

```lua
border = {
  highlight = "FloatBorder",
},
```

#### `border.style`

**Type:** `string` or `table`

Controls the styling of the border.

**Examples**

Can be one of the pre-defined styles: `"double"`, `"none"`, `"rounded"`, `"shadow"`, `"single"` or `"solid"`.

```lua
border = {
  style = "double",
},
```

List (`table`) of characters starting from the top-left corner and then clockwise:

```lua
border = {
  style = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
},
```

Map (`table`) with named characters:

```lua
border = {
  style = {
    top_left    = "╭", top    = "─",    top_right = "╮",
    left        = "│",                      right = "│",
    bottom_left = "╰", bottom = "─", bottom_right = "╯",
  },
},
```

If you don't need all these options, you can also pass the value of `border.style` to `border`
directly.

#### `border.text`

**Type:** `table`

Text displayed on the border (as title/footnote).

| Key              | Description                  |
| ---------------- | ---------------------------- |
| `"top"`          | top border text              |
| `"top_align"`    | top border text alignment    |
| `"bottom"`       | bottom border text           |
| `"bottom_align"` | bottom border text alignment |

Possible values for `"top_align"` and `"bottom_align"` are: `"left"`, `"right"` or `"center"` _(default)_.

**Examples**

```lua
border = {
  text = {
    top = "Popup Title",
    top_align = "center",
  },
},
```

---

### `ns_id`

**Type:** `number` or `string`

Namespace id (`number`) or name (`string`).

---

### `relative`

**Type:** `string` or `table`

This option affects how `position` and `size` are calculated.

**Examples**

Relative to cursor on current window:

```lua
relative = "cursor",
```

Relative to the current editor screen:

```lua
relative = "editor",
```

Relative to the current window (_default_):

```lua
relative = "win",
```

Relative to the window with specific id:

```lua
relative = {
  type = "win",
  winid = 5,
},
```

Relative to the buffer position:

```lua
relative = {
  type = "buf",
  -- zero-indexed
  position = {
    row = 5,
    col = 5,
  },
},
```

---

### `position`

**Type:** `number` or `percentage string` or `table`

Position is calculated from the top-left corner.

If `position` is `number` or `percentage string`, it applies to both `row` and `col`.
Or you can pass a table to set them separately.

For `percentage string`, position is calculated according to the option `relative`.
If `relative` is set to `"buf"` or `"cursor"`, `percentage string` is not allowed.

**Examples**

```lua
position = 50,
```

```lua
position = "50%",
```

```lua
position = {
  row = 30,
  col = 20,
},
```

```lua
position = {
  row = "20%",
  col = "50%",
},
```

---

### `size`

**Type:** `number` or `percentage string` or `table`

Determines the size of the popup.

If `size` is `number` or `percentage string`, it applies to both `width` and `height`.
You can also pass a table to set them separately.

For `percentage string`, `size` is calculated according to the option `relative`.
If `relative` is set to `"buf"` or `"cursor"`, window size is considered.

**Examples**

```lua
size = 50,
```

```lua
size = "50%",
```

```lua
size = {
  width = 80,
  height = 40,
},
```

```lua
size = {
  width = "80%",
  height = "60%",
},
```

---

### `enter`

**Type:** `boolean`

If `true`, the popup is entered immediately after mount.

**Examples**

```lua
enter = true,
```

---

### `focusable`

**Type:** `boolean`

If `false`, the popup can not be entered by user actions (wincmds, mouse events).

**Examples**

```lua
focusable = true,
```

---

### `zindex`

**Type:** `number`

Sets the order of the popup on z-axis.

Popup with higher the `zindex` goes on top of popups with lower `zindex`.

**Examples**

```lua
zindex = 50,
```

---

### `buf_options`

**Type:** `table`

Contains all buffer related options (check `:h options | /local to buffer`).

**Examples**

```lua
buf_options = {
  modifiable = false,
  readonly = true,
},
```

---

### `win_options`

**Type:** `table`

Contains all window related options (check `:h options | /local to window`).

**Examples**

```lua
win_options = {
  winblend = 10,
  winhighlight = "Normal:Normal",
},
```

## Methods

### `popup:mount()`

Mounts the popup.

**Examples**

```lua
popup:mount()
```

---

### `popup:unmount()`

Unmounts the popup.

**Examples**

```lua
popup:unmount()
```

---

### `popup:hide()`

Hides the popup window. Preserves the buffer (related content, autocmds and keymaps).

---

### `popup:show()`

Shows the hidden popup window.

---

### `popup:map(mode, key, handler, opts, force)`

Sets keymap for the popup.

If keymap was already set and `force` is not `true` it returns `false`, otherwise returns `true`.

**Parameters**

| Name      | Type          | Description                                                         |
| --------- | ------------- | ------------------------------------------------------------------- |
| `mode`    | `"n"` / `"i"` | check `:h :map-modes`                                               |
| `key`     | `string`      | key for the mapping                                                 |
| `handler` | `function`    | handler function for the mapping                                    |
| `opts`    | `table`       | check `:h :map-arguments` (including `noremap`, excluding `buffer`) |
| `force`   | `boolean`     | for overriding existing mapping                                     |

**Examples**

```lua
local ok = popup:map("n", "<esc>", function(bufnr)
  print("ESC pressed in Normal mode!")
end, { noremap = true })
```

---

### `popup:on(event, handler, options)`

Defines `autocmd` to run on specific events for this popup.

**Parameters**

| Name      | Type                  | Description                                |
| --------- | --------------------- | ------------------------------------------ |
| `event`   | `string[]` / `string` | check `:h events`                          |
| `handler` | `function`            | handler function for event                 |
| `options` | `table`               | keys `once`, `nested` and values `boolean` |

**Examples**

```lua
local event = require("nui.utils.autocmd").event

popup:on({ event.BufLeave }, function()
  popup:unmount()
end, { once = true })
```

`event` can be expressed as any of the followings:

```lua
{ event.BufLeave, event.BufDelete }
-- or
{ event.BufLeave, "BufDelete" }
-- or
event.BufLeave
-- or
"BufLeave"
-- or
"BufLeave,BufDelete"
```

---

### `popup:off(event)`

Removes `autocmd` defined with `popup:on({ ... })`

**Parameters**

| Name    | Type                  | Description       |
| ------- | --------------------- | ----------------- |
| `event` | `string[]` / `string` | check `:h events` |

**Examples**

```lua
popup:off("*")
```

---

### `popup:set_size(size)`

Sets the size of the popup.

**Parameters**

| Name     | Type                           |
| -------- | ------------------------------ |
| `width`  | `number` / `percentage string` |
| `height` | `number` / `percentage string` |

**Examples**

```lua
popup:set_size({ width = 80, height = 40 })
```

---

### `popup.border:set_text(edge, text, align)`

Sets border text.

**Parameters**

| Name    | Type                                        |
| ------- | ------------------------------------------- |
| `edge`  | `"top"` / `"bottom"` / `"left"` / `"right"` |
| `text`  | `string`                                    |
| `align` | `"left"` / `"right"`/ `"center"`            |

**Examples**

```lua
popup.border:set_text("bottom", "[Progress: 42%]", "right")
```
