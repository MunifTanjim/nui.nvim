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

### Window

```lua
local Window = require("nui.window")
```

#### Window:new

```lua
local window = Window:new({
  border = "rounded",
  position = "50%",
  size = {
    width = "80%",
    height = "60%",
  },
  opacity = 1,
})
```

**border**

`border` can be one of the followings:

- Presets: `"double"`, `"none"`, `"rounded"`, `"shadow"`, `"single"` or `"solid"`
- List (table) of characters starting from the top-left corner and then clockwise. For example:
  ```
  { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
  ```
- Map (table) with named characters. For example:
  ```
  {
    top_left    = "╭", top    = "─", top_right     = "╮",
    left        = "│",               right         = "│"
    bottom_left = "╰", bottom = "─", bottom_right  = "╯",
  }
  ```

You can also include a highlight for each character separately, just pass table
instead of string for those. For example: `{ "│", "FloatBorder" }`

**border_highlight**

`border_highlight` can be a string denoting the highlight group for the border characters.

**relative**

This option affects how `position` and `size` is calculated.

| Value                         | Description                              |
| ----------------------------- | ---------------------------------------- |
| `"cursor"`                    | relative to cursor on current window     |
| `"editor"` (_default_)        | relative to current editor screen        |
| `"win"` or `{}`               | relative to current window               |
| `{ window_id = <window-id> }` | relative to window with id `<window-id>` |

**position**

If `position` is number or percentage string, it applies to both row and col.
Or you can pass a table to set them separately.
Position is calculated from the top-left corner.

For percentage string, position is calculated according to the option `relative`
(if `relative` is set to `"cursor"`, percentage string is not allowed).

**size**

If `size` is number or percentage string, it applies to both width and height.
Or you can pass a table to set them separately.

For percentage string, size is calculated according to the option `relative`
(if `relative` is set to `"cursor"`, window size is considered).

**opacity**

`opacity` is a number between `0` (no transparency) and
`1` (completely transparency).

## License

Licensed under the MIT License. Check the [LICENSE](./LICENSE) file for details.
