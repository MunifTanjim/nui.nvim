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

## Parameters

_Signature:_ `NuiLine(texts?)`

### `texts`

**Type:** `table[]`

List of `NuiText` objects to set as initial texts.

**Example**

```lua
local text_one = NuiText("One")
local text_two = NuiText("Two")
local line = NuiLine({ text_one, text_two })
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

### `line:highlight(bufnr, ns_id, linenr)`

Applies highlight for the line.

**Parameters**

| Name     | Type     | Description                                    |
| -------- | -------- | ---------------------------------------------- |
| `bufnr`  | `number` | buffer number                                  |
| `ns_id`  | `number` | namespace id (use `-1` for fallback namespace) |
| `linenr` | `number` | line number (1-indexed)                        |

### `line:render(bufnr, ns_id, linenr_start, linenr_end?)`

Sets the line on buffer and applies highlight.

**Parameters**

| Name           | Type     | Description                                    |
| -------------- | -------- | ---------------------------------------------- |
| `bufnr`        | `number` | buffer number                                  |
| `ns_id`        | `number` | namespace id (use `-1` for fallback namespace) |
| `linenr_start` | `number` | start line number (1-indexed)                  |
| `linenr_end`   | `number` | end line number (1-indexed)                    |
