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

---

### `border`

**Type:** `'none'` or `table<string, string>` (optional)

Border characters to use, merged over the defaults (single-line box-drawing).
The customizable slots are `hor`, `ver`, `down_right`, `down_hor`, `down_left`,
`ver_right`, `ver_hor`, `ver_left`, `up_right`, `up_hor`, `up_left`.

Pass `'none'` for a **borderless** table: no horizontal border lines are drawn
and columns are separated by a single space.

---

### `buf_options`

**Type:** `table<string, any>` (optional)

Buffer options to set, merged over the scratch-buffer defaults.

## Methods

### `tbl:set_data`

_Signature:_ `tbl:set_data(data: any[]) -> NuiTable`

Replaces the table's data. Does not render; call `tbl:render()` afterwards.
Returns the table for chaining.

**Parameters**

| Name   | Type    | Description         |
| ------ | ------- | ------------------ |
| `data` | `any[]` | List of data items |

### `tbl:get_size`

_Signature:_ `tbl:get_size() -> { width: integer, height: integer } | nil`

Returns the dimensions (in cells) of the most recent render, or `nil` if the
table has not been rendered yet.

### `tbl:get_cell`

_Signature:_ `tbl:get_cell(position?: {integer, integer}) -> NuiTable.Cell | NuiTable.HeaderCell | nil`

Returns the cell relative to the one under the cursor, over the continuous
header + data + footer grid. Returns `nil` past the grid edges or when the
cursor isn't on a cell.

The returned value carries a `type` field: `NuiTable.Cell` (data cells) has
`type = "data"`; `NuiTable.HeaderCell` (header/footer cells) has
`type = "header"` or `"footer"`.

**Parameters**

| Name       | Type                   | Description                           |
| ---------- | ---------------------- | ------------------------------------- |
| `position` | `{ integer, integer }` | `(row, col)` tuple relative to cursor |

Vertical moves (`row`) keep the cursor's column; horizontal moves (`col`) step
cell-by-cell. When a vertical move lands on a border, it biases to the cell on
its right.

### `tbl:goto_cell`

_Signature:_ `tbl:goto_cell(position?: {integer, integer}) -> NuiTable.Cell | NuiTable.HeaderCell | nil`

Like `get_cell`, but also moves the cursor to the resolved cell: vertical moves
keep the cursor's column, horizontal moves snap to the target cell's content.
No-op (returns `nil`) if there's no cell there (e.g. at a grid edge). With no
`position`, it snaps the cursor to the current cell.

**Parameters**

| Name       | Type                   | Description                           |
| ---------- | ---------------------- | ------------------------------------- |
| `position` | `{ integer, integer }` | `(row, col)` tuple relative to cursor |

Returns the cell the cursor was moved to, if any.

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
