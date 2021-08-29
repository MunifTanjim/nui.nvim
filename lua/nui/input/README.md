# Input

Input is an abstraction layer on top of Popup.

You can use `vim.api` to manipulate it like any other buffer

## Options

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
```

**NOTE**: first argument accepts all options from the `popup` component

### `prompt`

- **Type:** `string`

Prefix in the input

### `default_value`

- **Type:** `string`

Default value placed in the input on mount
