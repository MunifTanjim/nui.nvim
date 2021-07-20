# nui.nvim

UI Component Library for Neovim.

## Requirements

- [Neovim 0.5.0](https://github.com/neovim/neovim/releases/tag/v0.5.0)

## Installation

Install the plugins with your preferred plugin manager. For example, with [`vim-plug`](https://github.com/junegunn/vim-plug):

```vim
Plug 'MunifTanjim/nui.nvim'
```

## Usage

### Popup

Popup is an abstraction layer on top of window.

Creates a new popup object (but does not mount it immediately).

```lua
local Popup = require("nui.popup")

local popup = Popup({
  border = {
    style = "rounded",
    highlight = "FloatBorder",
  },
  position = "50%",
  size = {
    width = "80%",
    height = "60%",
  },
  opacity = 1,
})
```

**border**

`border` accepts a table with these keys: `style`, `highlight` and `text`.

`border.style` can be one of the followings:

- Pre-defined style: `"double"`, `"none"`, `"rounded"`, `"shadow"`, `"single"` or `"solid"`
- List (table) of characters starting from the top-left corner and then clockwise. For example:
  ```lua
  { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
  ```
- Map (table) with named characters. For example:
  ```lua
  {
    top_left    = "╭", top    = "─", top_right     = "╮",
    left        = "│",               right         = "│"
    bottom_left = "╰", bottom = "─", bottom_right  = "╯",
  }
  ```

`border.highlight` can be a string denoting the highlight group name for the border characters.

`border.text` can be an table with the following keys:

| Key              | Description                  |
| ---------------- | ---------------------------- |
| `"top"`          | top border text              |
| `"top_align"`    | top border text alignment    |
| `"bottom"`       | bottom border text           |
| `"bottom_align"` | bottom border text alignment |

Possible values for `"top_align"` and `"bottom_align"` are: `"left"`, `"right"` or `"center"` _(default)_.

For example:

```lua
{
  top = "Popup Title",
  top_align = "center",
}
```

If you don't need all these options, you can also pass the value of `border.style` to `border`
directly.

**relative**

This option affects how `position` and `size` is calculated.

| Value                                     | Description                              |
| ----------------------------------------- | ---------------------------------------- |
| `"cursor"`                                | relative to cursor on current window     |
| `"editor"`                                | relative to current editor screen        |
| `"win"` (_default_)                       | relative to current window               |
| `{ type = "win", winid = <winid> }`       | relative to window with id `<winid>`     |
| `{ type = "buf", position = <Position> }` | relative to buffer position `<Position>` |

Here `<Position>` is a table with keys `row`, `col` and values are zero-indexed numbers.

**position**

If `position` is number or percentage string, it applies to both row and col.
Or you can pass a table to set them separately.
Position is calculated from the top-left corner.

For percentage string, position is calculated according to the option `relative`
(if `relative` is set to `"buf"` or `"cursor"`, percentage string is not allowed).

**size**

If `size` is number or percentage string, it applies to both width and height.
Or you can pass a table to set them separately.

For percentage string, size is calculated according to the option `relative`
(if `relative` is set to `"buf"` or `"cursor"`, window size is considered).

**padding**

`padding` can be a table with number of cells for top, right, bottom and left.
It behaves like [CSS](https://developer.mozilla.org/en-US/docs/Web/CSS) padding.
For example:

```lua
{ 1, 2 }
```

It will set padding of `1` for top/bottom and `2` for left/right.

**enter**

If `enter` is `true`, the popup is entered immediately after mount.

**zindex**

`zindex` is a number used to order the position of popups on z-axis.
Popup with higher `zindex` goes on top of popups with lower `zindex`.

**buf_options**

Table containing buffer options to set for this popup. For example:

```lua
{
  modifiable = false,
  readonly = true,
}
```

**win_options**

Table containing window options to set for this popup. For example:

```lua
{
  winblend = 10,
  winhighlight = "Normal:Normal",
}
```

#### popup:mount()

Mounts the popup.

```lua
popup:mount()
```

#### popup:unmount()

Unmounts the popup.

```lua
popup:unmount()
```

#### popup:map(mode, key, handler, opts, force)

Sets keymap for this popup. If keymap was already set and `force` is not `true`
returns `false`, otherwise returns `true`.

For example:

```lua
local ok = popup:map("n", "<esc>", function(bufnr)
  print("ESC pressed in Normal mode!")
end, { noremap = true })
```

#### popup:on(event, handler, options)

Defines `autocmd` to run on specific events for this popup. For example:

```lua
local event = require("nui.utils.autocmd").event

popup:on({ event.BufLeave }, function()
  popup:unmount()
end, { once = true })
```

#### popup:off(event)

Removes `autocmd` defined with `popup:on(...)`. For example:

```lua
popup:off("*")
```

#### popup.border:set_text(edge, text, align)

Sets border text. For example:

```lua
popup.border:set_text("bottom", "[Progress: 42%]", "right")
```

### Input

`Input` is an abstraction layer on top of `Popup`.

Creates a new input object (but does not mount it immediately).

```lua
local Input = require("nui.input")

local input = Input(popup_options, {
  prompt = "> ",
  default_value = "42",
  on_close = function()
    print("Input closed!")
  end,
  on_submit = function(value)
    print("Value submitted: ", value)
  end,
  on_change = function(value)
    print("Value changed: ", value)
  end,
})
```

All the methods `Popup` methods is also available for `Input`. It uses
prompt buffer (check `:h prompt-buffer`) for its popup window.

If you provide the `on_change` function, it'll be run everytime value changes.

Pressing `<CR>` runs the `on_submit` callback function and closes the window.
Pressing `<C-c>` runs the `on_close` callback function and closes the window.

Of course, you can override the default keymaps and add more. For example:

```lua
-- close the input window by pressing `<Esc>` on normal mode
input:map("n", "<Esc>", input.input_props.on_close, { noremap = true })
```

## License

Licensed under the MIT License. Check the [LICENSE](./LICENSE) file for details.
