# NuiTable

NuiTable can render table-like structured content on the buffer.

**Examples**

```lua
local NuiTable = require("nui.table")

local tbl = NuiTable({
  bufnr = bufnr,
  columns = {
    {
      align = "center",
      header = "Name",
      columns = {
        { accessor_key = "firstName", header = "First" },
        {
          id = "lastName",
          accessor_fn = function(row)
            return row.lastName
          end,
          header = "Last",
        },
      },
    },
    {
      align = "right",
      accessor_key = "age",
      cell = function(cell)
        return Text(tostring(cell.get_value()), "DiagnosticInfo")
      end,
      header = "Age",
    },
  },
  data = {
    { firstName = "John", lastName = "Doe", age = 42 },
    { firstName = "Jane", lastName = "Doe", age = 27 },
  },
})

tbl:render()
```

## Options

### `bufnr`

**Type:** `number`

Id of the buffer where the table will be rendered.

---

### `ns_id`

**Type:** `number` or `string`

Namespace id (`number`) or name (`string`).

---

### `columns`

**Type:** `NuiTable.ColumnDef[]`

List of `NuiTable.ColumnDef` objects.

---

### `data`

**Type:** `any[]`

List of data items.

## Methods

### `tbl:get_cell`

_Signature:_ `tbl:get_cell() -> NuiTable.Cell | nil`

Returns the `cell` if found.

### `tbl:refresh_cell`

_Signature:_ `tbl:refresh_cell(cell: NuiTable.Cell) -> nil`

Refreshes the `cell` on buffer.

**Parameters**

| Name   | Type            | Description |
| ------ | --------------- | ----------- |
| `cell` | `NuiTable.Cell` | cell        |

### `tbl:render`

_Signature:_ `tbl:render(linenr_start?: integer) -> nil`

Renders the table on buffer.

| Name           | Type              | Description                   |
| -------------- | ----------------- | ----------------------------- |
| `linenr_start` | `integer` / `nil` | start line number (1-indexed) |

## Wiki Page

You can find additional documentation/examples/guides/tips-n-tricks in [nui.table wiki page](https://github.com/MunifTanjim/nui.nvim/wiki/nui.table).
