# Split

Split is can be used to split your current window or editor.

```lua
local Split = require("nui.split")

local split = Split({
  relative = "editor",
  position = "bottom",
  size = "20%",
})
```

You can manipulate the assocciated buffer and window using the
`split.bufnr` and `split.winid` properties.

## Options

### `relative`

| Value               | Description                 |
| ------------------- | --------------------------- |
| `"editor"`          | split current editor screen |
| `"win"` (_default_) | split current window        |

This option also affects how `size` is calculated.

### `position`

`position` can be one of: `"top"`, `"right"`, `"bottom"` or `"left"`.

### `size`

`size` can be `number` or `percentage string`.

For `percentage string`, size is calculated according to the option `relative`.

### `buf_options`

Table containing buffer options to set for this split.

### `win_options`

Table containing window options to set for this split.

## Methods

[Methods from `nui.popup`](/lua/nui/popup#methods) are also available for `nui.split`.

## Wiki Page

You can find additional documentation/examples/guides/tips-n-tricks in [nui.split wiki page](https://github.com/MunifTanjim/nui.nvim/wiki/nui.split).
