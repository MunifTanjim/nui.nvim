![GitHub Workflow Status: CI](https://img.shields.io/github/workflow/status/MunifTanjim/nui.nvim/CI/main?label=CI&style=for-the-badge)
[![Coverage](https://img.shields.io/codecov/c/gh/MunifTanjim/nui.nvim/master?style=for-the-badge)](https://codecov.io/gh/MunifTanjim/nui.nvim)
![License](https://img.shields.io/github/license/MunifTanjim/nui.nvim?color=%23000080&style=for-the-badge)

# nui.nvim

UI Component Library for Neovim.

## Requirements

- [Neovim 0.5.0](https://github.com/neovim/neovim/releases/tag/v0.5.0)

## Installation

Install the plugins with your preferred plugin manager. For example, with [`vim-plug`](https://github.com/junegunn/vim-plug):

```vim
Plug 'MunifTanjim/nui.nvim'
```

## Blocks

### [NuiText](lua/nui/text)

Quickly add highlighted text on the buffer.

**[Check Detailed Documentation for `nui.text`](lua/nui/text)**

**[Check Wiki Page for `nui.text`](https://github.com/MunifTanjim/nui.nvim/wiki/nui.text)**

### [NuiLine](lua/nui/line)

Quickly add line containing highlighted text chunks on the buffer.

**[Check Detailed Documentation for `nui.line`](lua/nui/line)**

**[Check Wiki Page for `nui.line`](https://github.com/MunifTanjim/nui.nvim/wiki/nui.line)**

### [NuiTree](lua/nui/tree)

Quickly render tree-like structured content on the buffer.

**[Check Detailed Documentation for `nui.tree`](lua/nui/tree)**

**[Check Wiki Page for `nui.tree`](https://github.com/MunifTanjim/nui.nvim/wiki/nui.tree)**

## Components

### [Popup](lua/nui/popup)

![Popup GIF](https://github.com/MunifTanjim/nui.nvim/wiki/media/popup.gif)

```lua
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local popup = Popup({
  enter = true,
  focusable = true,
  border = {
    style = "rounded",
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

-- mount/open the component
popup:mount()

-- unmount component when cursor leaves buffer
popup:on(event.BufLeave, function()
  popup:unmount()
end)

-- set content
vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, { "Hello World" })
```

**[Check Detailed Documentation for `nui.popup`](lua/nui/popup)**

**[Check Wiki Page for `nui.popup`](https://github.com/MunifTanjim/nui.nvim/wiki/nui.popup)**

### [Input](lua/nui/input)

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

-- mount/open the component
input:mount()

-- unmount component when cursor leaves buffer
input:on(event.BufLeave, function()
  input:unmount()
end)
```

**[Check Detailed Documentation for `nui.input`](lua/nui/input)**

**[Check Wiki Page for `nui.input`](https://github.com/MunifTanjim/nui.nvim/wiki/nui.input)**

### [Menu](lua/nui/menu)

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
    Menu.separator("Menu Group", {
      char = "-",
      text_align = "right",
    }),
    Menu.item("Item 3"),
  },
  max_width = 20,
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

-- mount the component
menu:mount()

-- close menu when cursor leaves buffer
menu:on(event.BufLeave, menu.menu_props.on_close, { once = true })
```

**[Check Detailed Documentation for `nui.menu`](lua/nui/menu)**

**[Check Wiki Page for `nui.menu`](https://github.com/MunifTanjim/nui.nvim/wiki/nui.menu)**

### [Split](lua/nui/split)

![Split GIF](https://github.com/MunifTanjim/nui.nvim/wiki/media/split.gif)

```lua
local Split = require("nui.split")
local event = require("nui.utils.autocmd").event

local split = Split({
  relative = "editor",
  position = "bottom",
  size = "20%",
})

-- mount/open the component
split:mount()

-- unmount component when cursor leaves buffer
split:on(event.BufLeave, function()
  split:unmount()
end)
```

**[Check Detailed Documentation for `nui.split`](lua/nui/split)**

**[Check Wiki Page for `nui.split`](https://github.com/MunifTanjim/nui.nvim/wiki/nui.split)**

## License

Licensed under the MIT License. Check the [LICENSE](./LICENSE) file for details.
