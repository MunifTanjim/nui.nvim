# Split

Spawns a split buffer

You can use `vim.api` to manipulate it like any other buffer

## Options

```lua
local Split = require("nui.split")

local split = Split({
  relative = "editor",
  position = "bottom",
  size = "20%",
})
```

It has the usual `:mount`, `:unmount`, `:map`, `:on` and `:off` methods.

**relative**

| Value               | Description                 |
| ------------------- | --------------------------- |
| `"editor"`          | split current editor screen |
| `"win"` (_default_) | split current window        |

This option also affects how `size` is calculated.

**position**

`position` can be one of: `"top"`, `"right"`, `"bottom"` or `"left"`.

**size**

`size` can be number or percentage string.

For percentage string, size is calculated according to the option `relative`.

**buf_options**

Table containing buffer options to set for this split.

**win_options**

Table containing window options to set for this split.

## Methods

### split:hide()

Hides the split window.

### split:show()

Shows the hidden split window.
