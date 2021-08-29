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

**Component API is available [HERE](lua/popup/README.md)**

### Input

![Input GIF](https://github.com/MunifTanjim/nui.nvim/wiki/media/input.gif)

```lua
local Input = require("nui.input")
local event = require("nui.utils.autocmd").event

local input = Input({
  position = "20%",
  size = {
      width = 20,
      height = 2,
  },
  relative = "editor",
  border = {
    highlight = "MyHighlightGroup",
    style = "single",
    text = {
        top = "How old are you?",
        top_align = "center",
    },
  },
  win_options = {
    winblend = 10,
    winhighlight = "Normal:Normal",
  },
}, {
  prompt = "> ",
  default_value = "42",
  on_close = function()
    print("Input closed!")
  end,
  on_submit = function(value)
    print("You are " .. value .. " years old")
  end,
})

-- Mount/open the input
input:mount()

-- Unmount input after its buffer gets closed
input:on(event.BufHidden, function()
    vim.schedule(function()
        input:unmount()
    end)
end)
```

**Component API is available [HERE](lua/input/README.md)**

### Menu

![Menu GIF](https://github.com/MunifTanjim/nui.nvim/wiki/media/menu.gif)

```lua
local Menu = require("nui.menu")
local event = require("nui.utils.autocmd").event

local menu = Menu({
  position = "20%",
  size = {
    width = 20,
    height = 2,
  },
  relative = "editor",
  border = {
    highlight = "MyHighlightGroup",
    style = "single",
    text = {
      top = "Choose Something",
      top_align = "center",
    },
  },
  win_options = {
    winblend = 10,
    winhighlight = "Normal:Normal",
  },
}, {
  lines = {
    Menu.item("Item 1"),
    Menu.item("Item 2"),
    Menu.separator("Menu Group"),
    Menu.item("Item 3"),
  },
  max_width = 20,
  separator = {
    char = "-",
    text_align = "right",
  },
  keymap = {
    focus_next = { "j", "<Down>", "<Tab>" },
    focus_prev = { "k", "<Up>", "<S-Tab>" },
    close = { "<Esc>", "<C-c>" },
    submit = { "<CR>", "<Space>" },
  },
  on_close = function()
    print("CLOSED")
  end,
  on_submit = function(item)
    print("SUBMITTED", vim.inspect(item))
  end,
})

-- Mount/open the popup
menu:mount()

-- Unmount popup after its buffer gets closed
menu:on(event.BufHidden, function()
  vim.schedule(function()
    menu:unmount()
  end)
end)
```

**Component API is available [HERE](lua/menu/README.md)**

### Split

![Split GIF](https://github.com/MunifTanjim/nui.nvim/wiki/media/split.gif)

```lua
local Split = require("nui.split")
local event = require("nui.utils.autocmd").event

local split = Split({
  relative = "editor",
  position = "bottom",
  size = "20%",
})

-- Mount/open the popup
split:mount()

-- Unmount popup after its buffer gets closed
split:on(event.BufHidden, function()
  vim.schedule(function()
    split:unmount()
  end)
end)
```

**Component API is available [HERE](lua/split/README.md)**

## License

Licensed under the MIT License. Check the [LICENSE](./LICENSE) file for details.
