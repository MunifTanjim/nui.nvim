# NuiText

NuiText is an abstraction layer on top of the following native functions:

- `vim.api.nvim_buf_set_text` (check `:h nvim_buf_set_text()`)
- `vim.api.nvim_buf_add_highlight` (check `:h nvim_buf_add_highlight()`)

It helps you set text and add highlight for it on the buffer.

```lua
local NuiText = require("nui.text")

local text = NuiText("Something Went Wrong!", "Error")

local bufnr, linenr, byte_pos = 0, 1, 0

text:render(bufnr, linenr, byte_pos, linenr, byte_pos)
```

## Parameters

_Signature:_ `NuiText(content, highlight?)`

### `content`

**Type:** `string`

Text content.

### `highlight`

**Type:** `string` or `table`

Highlight information.

It can be a `string` specifying the highlight group name,
or a `table` with the following keys:

| Key          | Description          |
| ------------ | -------------------- |
| `"hl_group"` | highlight group name |
| `"ns_id"`    | namespace id         |

## Methods

### `text:set(content, highlight?)`

Sets the text content and highlight information.

**Parameters**

| Name        | Type                | Description           |
| ----------- | ------------------- | --------------------- |
| `content`   | `string`            | text content          |
| `highlight` | `string` or `table` | highlight information |

These parameters are exactly the same as `NuiText` parameters.

### `text:content()`

Returns the text content.

### `text:length()`

Returns the byte length of the text.

### `text:width()`

Returns the character length of the text.

### `text:highlight(bufnr, linenr, byte_start, ns_id)`

Applies highlight for the text.

**Parameters**

| Name         | Type     | Description                                        |
| ------------ | -------- | -------------------------------------------------- |
| `bufnr`      | `number` | buffer number                                      |
| `linenr`     | `number` | line number (1-indexed)                            |
| `byte_start` | `number` | start position of the text on the line (0-indexed) |
| `ns_id`      | `number` | namespace id                                       |

### `text:render(bufnr, linenr_start, byte_start, linenr_end, byte_end)`

Sets the text on buffer and applies highlight.

**Parameters**

| Name           | Type     | Description                                        |
| -------------- | -------- | -------------------------------------------------- |
| `bufnr`        | `number` | buffer number                                      |
| `linenr_start` | `number` | start line number (1-indexed)                      |
| `byte_start`   | `number` | start position of the text on the line (0-indexed) |
| `linenr_end`   | `number` | end line number (1-indexed)                        |
| `byte_end`     | `number` | end position of the text on the line (0-indexed)   |
| `ns_id`        | `number` | namespace id                                       |

### `text:render_char(bufnr, linenr_start, char_start, linenr_end, char_end)`

Sets the text on buffer and applies highlight.

This does the thing as `text:render` method, but you can use character count
instead of byte count. It will convert multibyte character count to appropriate
byte count for you.

**Parameters**

| Name           | Type     | Description                                        |
| -------------- | -------- | -------------------------------------------------- |
| `bufnr`        | `number` | buffer number                                      |
| `linenr_start` | `number` | start line number (1-indexed)                      |
| `char_start`   | `number` | start position of the text on the line (0-indexed) |
| `linenr_end`   | `number` | end line number (1-indexed)                        |
| `char_end`     | `number` | end position of the text on the line (0-indexed)   |
| `ns_id`        | `number` | namespace id                                       |
