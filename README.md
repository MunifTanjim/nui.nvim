# nui.nvim

UI Component Library for Neovim.

## Requirements

- [Neovim 0.5.0](https://github.com/neovim/neovim/releases/tag/v0.5.0)

## Installation

Install the plugins with your preferred plugin manager. For example, with [`vim-plug`](https://github.com/junegunn/vim-plug):

```vim
Plug 'MunifTanjim/nui.nvim'
```

## Components

### Popup

![Popup GIF](https://github.com/MunifTanjim/nui.nvim/wiki/media/popup.gif)

```lua
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      highlight = "FloatBorder",
    },
    position = "50%",
    size = {
      width = "80%",
      height = "60%",
    },
    buf_options = {
      modifiable = true,
      readonly = false,
    },
})

-- Mount/open the popup
popup:mount()

-- Unmount popup after its buffer gets closed
popup:on(event.BufHidden, function()
  vim.schedule(function()
      popup:unmount()
  end)
end)

-- Set content inside popup
vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, { "Hello World" })
```

**Component API is available [HERE](doc/components/popup.md)**

## License

Licensed under the MIT License. Check the [LICENSE](./LICENSE) file for details.
