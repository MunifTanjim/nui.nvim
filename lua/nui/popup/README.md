# Popup

Spawns a buffer inside a popup

You can use `vim.api` to manipulate it like any other buffer

## Options

```lua
local Popup = require("nui.popup")

local popup = Popup({
  position = "20%",
  size = {
    width = 20,
    height = 10,
  },
  enter = true,
  focusable = true,
  zindex = 10,
  relative = "editor",
  border = {
    highlight = "MyHighlightGroup",
    padding = {
      top = 2,
        bottom = 2,
        left = 3,
        right = 3,
    },
    style = "double",
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
)
```

### `border`

- **Type:** `table`

Contains all border related options

#### `border.padding`

- **Type:** `table`

Controls the popup padding. Behaves like [CSS padding](https://developer.mozilla.org/en-US/docs/Web/CSS/padding)

**Examples**

```lua
border = {
  padding = { top = 10, bottom = 20, left = 15, right = 20 }
}
```

```lua
border = {
  padding = { 10, 30, 40, 10 }
}
```

#### `border.highlight`

- **Type:** `string`

Highlight group name for the border characters.

```lua
border = {
  highlight = "MyHighlightGroup"
}
```

#### `border.style`

- **Type:** `string` or `table`

Controls the styling of the border

**Examples**

Can be: `double`, `none`, `rounded`, `shadow`, `single`, `solid`

```lua
border = {
  style = "double"
}
```

Order is clockwise

```lua
border = {
  style = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
}
```

```lua
border = {
  style = {
    top_left = "╭",
    top = "─",
    top_right = "╮",
    left = "│",
    right = "│",
    bottom_left = "╰",
    bottom = "─",
    bottom_right = "╯",
  }
}
```

#### `border.text`

- **Type:** `string` or `table`

Text displayed in the border to serve as a title. `top_align` and `bottom_align`
can be: `left`, `right`, `center`

**Examples**

```lua
border = {
  text = {
    top = "I am top title",
    top_align = "center",
    bottom = "I am bottom title",
    bottom_align = "left",
  }
}
```

---

### `relative`

- **Type:** `string` or `table`

This option affects how `position` and `size` is calculated.

**Examples**

Relative to cursor on current window

```lua
relative = "cursor"
```

Relative to the current editor on current window

```lua
relative = "editor"
```

Relative to the current window

```lua
relative = "win"
```

Relative to the window of `id`

```lua
relative = {
  type = "win",
  winid = 5,
}
```

Relative to the buffer's `position`

```lua
relative = {
  type = "buf",
  position = {
    row = 5,
    col = 5,
  },
}
```

---

### `position`

- **Type:** `number` or `percentage string` or `table`

If `position` is `number` or `percentage string`, it applies to both `row` and `col`.
Position is calculated from the top-left corner.

For `percentage`, position is calculated according to the option `relative`.
If `relative` is set to `"buf"` or `"cursor"`, `percentage string` is not allowed

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
  col = 20
}
```

```lua
position = {
  row = "30%",
  col = "20%"
}
```

---

### `size`

- **Type:** `number` or `percentage string` or `table`

Determines the size of the popup. For `percentage`, `size` is calculated according to the option `relative`.
If `relative` is set to `buf` or `cursor`, window `size` is considered

If `size` is `number` or `percentage`, it applies to both `width` and `height`.
You can also pass a table to set them separately.

**Examples**

```lua
size = 50,
```

```lua
size = "50%",
```

```lua
size = {
  width = 30,
  height = 50,
}
```

```lua
size = {
  width = "30%",
  height = "50%",
}
```

---

### `enter`

- **Type:** `boolean`

If `true`, the popup is auto-entered after mount

**Examples**

```lua
enter = true,
```

---

### `focusable`

- **Type:** `boolean`

Is `false`, the popup can not be entered by user actions (wincmds, mouse events)

**Examples**

```lua
focusable = true,
```

---

### `zindex`

- **Type:** `number`

Sets the order of the popup on z-axis. Popup with higher the `zindex` goes on
top of popups with lower `zindex`

**Examples**

```lua
zindex = 20,
```

---

### `buf_options`

- **Type:** `table`

Contains all buffer related options from native buffer options `:h options /local to buffer`

**Examples**

```lua
buf_options = {
  modifiable = false,
  readonly = true,
},
```

---

### `win_options`

- **Type:** `table`

Contains all window related options from native buffer options `:h options /local to window`

**Examples**

```lua
win_options = {
  winblend = 10,
  winhighlight = "Normal:Normal",
},
```

## Methods

### `popup:mount()`

Mounts the popup

```lua
popup:mount()
```

---

### `popup:unmount()`

Unmounts the popup

```lua
popup:unmount()
```

---

### `popup:map(mode, key, handler, opts, force)`

Sets keymap for this popup.

If keymap was already set and `force` is not `true` it returns `false`, otherwise returns `true`

```lua
local ok = popup:map("n", "<esc>", function(bufnr)
  print("ESC pressed in Normal mode!")
end, { noremap = true })
```

**options**

| Value     | Description                                                                                                        |
| --------- | ------------------------------------------------------------------------------------------------------------------ |
| `mode`    | Neovim `mode` <br> See `:h vim-modes`                                                                              |
| `key`     | Trigger for the map                                                                                                |
| `handler` | Function to fire on that key trigger                                                                               |
| `opts`    | Can be a table with `"expr"` \| `"noremap"` \| `"nowait"` \| `"script"` \| `"silent"` \| `"unique"` or a `boolean` |
| `force`   | `boolean`                                                                                                          |

---

### `popup:on(event, handler, options)`

Defines `autocmd` to run on specific events for this popup

```lua
local event = require("nui.utils.autocmd").event

popup:on({ event.BufLeave }, function()
  popup:unmount()
end, { once = true })
```

**options**

| Value     | Description                                           |
| --------- | ----------------------------------------------------- |
| `event`   | Neovim `event` <br> See `:h events`                   |
| `handler` | Function to fire on that event                        |
| `options` | Can be a table with `once` \| `nested` or a `boolean` |

**Event Examples**

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

```lua
popup:off("*")
```

**options**

| Value   | Description                         |
| ------- | ----------------------------------- |
| `event` | Neovim `event` <br> See `:h events` |

---

### `popup:set_size(size)`

Sets the size of the popup

```lua
popup:set_size({ width = 80, height = 40 })
```

**options**

| Value    | Description              |
| -------- | ------------------------ |
| `width`  | `number` or `percentage` |
| `height` | `number` or `percentage` |

---

### `popup.border:set_text(edge, text, align)`

Sets border text

```lua
popup.border:set_text("bottom", "[Progress: 42%]", "right")
```

**options**

| Value   | Description                      |
| ------- | -------------------------------- |
| `edge`  | `top`, `bottom`, `left`, `right` |
| `text`  | String to set                    |
| `align` | `left`, `right`, `center`        |
