# Input

Input is an abstraction layer on top of Popup.

It uses prompt buffer (check `:h prompt-buffer`) for its popup window.

```lua
local Input = require("nui.input")
local event = require("nui.utils.autocmd").event

local popup_options = {
  relative = "cursor",
  position = {
    row = 1,
    col = 0,
  },
  size = 20,
  border = {
    style = "rounded",
    highlight = "FloatBorder",
    text = {
      top = "[Input]",
      top_align = "left",
    },
  },
  win_options = {
    winhighlight = "Normal:Normal",
  },
}

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

If you provide the `on_change` function, it'll be run everytime value changes.

Pressing `<CR>` runs the `on_submit` callback function and closes the window.
Pressing `<C-c>` runs the `on_close` callback function and closes the window.

Of course, you can override the default keymaps and add more. For example:

```lua
-- close the input window by pressing `<Esc>` on normal mode
input:map("n", "<Esc>", input.input_props.on_close, { noremap = true })
```

You can manipulate the assocciated buffer and window using the
`split.bufnr` and `split.winid` properties.

**NOTE**: the first argument accepts options for `nui.popup` component.

## Options

### `prompt`

**Type:** `string` or `NuiText`

Prefix in the input.

### `default_value`

**Type:** `string`

Default value placed in the input on mount

### `on_close`

Callback function, called when input is closed.

### `on_submit`

Callback function, called when input value is submitted.

### `on_change`

Callback function, called when input value is changed.

## Methods

Methods from `nui.popup` are also available for `nui.input`.
