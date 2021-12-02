# NuiLine

NuiLine is an abstraction layer on top of the following native functions:

- `vim.api.nvim_buf_set_lines` (check `:h nvim_buf_set_lines()`)
- `vim.api.nvim_buf_set_text` (check `:h nvim_buf_set_text()`)
- `vim.api.nvim_buf_add_highlight` (check `:h nvim_buf_add_highlight()`)

It helps you create line on the buffer containing multiple [`NuiText`](../text)s.

```lua
local NuiLine = require("nui.line")

local line = NuiLine()

line:append("Something Went Wrong!", "Error")

local bufnr, linenr = 0, 1

line:render(bufnr, linenr)
```

## Methods

### `line:append(text, highlight?)`

Adds a chunk of text to the line.

**Parameters**

| Name        | Type                  | Description           |
| ----------- | --------------------- | --------------------- |
| `text`      | `string` or `NuiText` | text content          |
| `highlight` | `string` or `table`   | highlight information |

If `text` is `string`, these parameters are passed to `NuiText`
and a `NuiText` object is returned.

It `text` is already a `NuiText` object, it is returned unchanged.

### `line:content()`

Returns the line content.

### `line:highlight(bufnr, linenr, ns_id?)`

Applies highlight for the line.

**Parameters**

| Name     | Type     | Description             |
| -------- | -------- | ----------------------- |
| `bufnr`  | `number` | buffer number           |
| `linenr` | `number` | line number (1-indexed) |
| `ns_id`  | `number` | namespace id            |

### `line:render(bufnr, linenr_start, linenr_end?, ns_id?)`

Sets the line on buffer and applies highlight.

**Parameters**

| Name           | Type     | Description                   |
| -------------- | -------- | ----------------------------- |
| `bufnr`        | `number` | buffer number                 |
| `linenr_start` | `number` | start line number (1-indexed) |
| `linenr_end`   | `number` | end line number (1-indexed)   |
| `ns_id`        | `number` | namespace id                  |
