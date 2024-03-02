local Object = require("nui.object")
local Text = require("nui.text")
local Line = require("nui.line")
local _ = require("nui.utils")._

-- luacheck: push no max comment line length

---@alias nui_table_border_char_name 'down_right'|'hor'|'down_hor'|'down_left'|'ver'|'ver_left'|'ver_hor'|'ver_left'|'up_right'|'up_hor'|'up_left'

---@alias _nui_table_header_kind
---| -1 -- footer
---|  1 -- header

---@class nui_t_list<T>: { [integer]: T, len: integer }

-- luacheck: pop

---@type table<nui_table_border_char_name,string>
local default_border = {
  hor = "─",
  ver = "│",
  down_right = "┌",
  down_hor = "┬",
  down_left = "┐",
  ver_right = "├",
  ver_hor = "┼",
  ver_left = "┤",
  up_right = "└",
  up_hor = "┴",
  up_left = "┘",
}

---@param internal nui_table_internal
---@param columns NuiTable.ColumnDef[]
---@param parent? NuiTable.ColumnDef
---@param depth? integer
local function prepare_columns(internal, columns, parent, depth)
  for _, col in ipairs(columns) do
    if col.header then
      internal.has_header = true
    end

    if col.footer then
      internal.has_footer = true
    end

    if not col.id then
      if col.accessor_key then
        col.id = col.accessor_key
      elseif type(col.header) == "string" then
        col.id = col.header --[[@as string]]
      elseif type(col.header) == "table" then
        col.id = (col.header --[[@as NuiText|NuiLine]]):content()
      end
    end

    if not col.id then
      error("missing column id")
    end

    if col.accessor_key and not col.accessor_fn then
      col.accessor_fn = function(row)
        return row[col.accessor_key]
      end
    end

    col.depth = depth or 0
    col.parent = parent

    if parent and not col.header then
      col.header = col.id
      internal.has_header = true
    end

    if col.columns then
      prepare_columns(internal, col.columns, col, col.depth + 1)
    else
      table.insert(internal.columns, col)
    end

    if col.depth == 0 then
      table.insert(internal.headers, col)
    else
      internal.headers.depth = math.max(internal.headers.depth, col.depth + 1)
    end

    if not col.align then
      col.align = "left"
    end

    if not col.width then
      col.width = 0
    end
  end
end

---@class NuiTable.ColumnDef
---@field accessor_fn? fun(original_row: table, index: integer): string|NuiText|NuiLine
---@field accessor_key? string
---@field align? nui_t_text_align
---@field cell? fun(info: NuiTable.Cell): string|NuiText|NuiLine
---@field columns? NuiTable.ColumnDef[]
---@field footer? string|NuiText|NuiLine|fun(info: { column: NuiTable.Column }): string|NuiText|NuiLine
---@field header? string|NuiText|NuiLine|fun(info: { column: NuiTable.Column }): string|NuiText|NuiLine
---@field id? string
---@field max_width? integer
---@field min_width? integer
---@field width? integer

---@class NuiTable.Column
---@field accessor_fn? fun(original_row: table, index: integer): string|NuiText|NuiLine
---@field accessor_key? string
---@field align nui_t_text_align
---@field columns? NuiTable.ColumnDef[]
---@field depth integer
---@field id string
---@field parent? NuiTable.Column
---@field width integer

---@class NuiTable.Row
---@field id string
---@field index integer
---@field original table

---@class NuiTable.Cell
---@field column NuiTable.Column
---@field content NuiText|NuiLine
---@field get_value fun(): string|NuiText|NuiLine
---@field row NuiTable.Row
---@field range table<1|2|3|4, integer> -- [start_row, start_col, end_row, end_col]

---@class nui_table_internal
---@field border table
---@field buf_options table<string, any>
---@field headers NuiTable.Column[]|{ depth: integer }
---@field columns NuiTable.ColumnDef[]
---@field data table[]
---@field has_header boolean
---@field has_footer boolean
---@field linenr table<1|2, integer>
---@field data_linenrs integer[]
---@field data_grid nui_t_list<NuiTable.Cell[]>

---@class nui_table_options
---@field bufnr integer
---@field ns_id integer|string
---@field columns NuiTable.ColumnDef[]
---@field data table[]

---@class NuiTable
---@field private _ nui_table_internal
---@field bufnr integer
---@field ns_id integer
local Table = Object("NuiTable")

---@param options nui_table_options
function Table:init(options)
  if options.bufnr then
    if not vim.api.nvim_buf_is_valid(options.bufnr) then
      error("invalid bufnr " .. options.bufnr)
    end

    self.bufnr = options.bufnr
  end

  if not self.bufnr then
    error("missing bufnr")
  end

  self.ns_id = _.normalize_namespace_id(options.ns_id)

  local border = vim.tbl_deep_extend("keep", options.border or {}, default_border)

  self._ = {
    buf_options = vim.tbl_extend("force", {
      bufhidden = "hide",
      buflisted = false,
      buftype = "nofile",
      modifiable = false,
      readonly = true,
      swapfile = false,
      undolevels = 0,
    }, options.buf_options or {}),
    border = border,

    headers = { depth = 1 },
    columns = {},
    data = options.data or {},

    has_header = false,
    has_footer = false,

    linenr = {},
    data_linenrs = {},
  }

  prepare_columns(self._, options.columns or {})

  _.set_buf_options(self.bufnr, self._.buf_options)
end

---@param current_width integer
---@param min_width? integer
---@param max_width? integer
---@param content_width integer
local function get_col_width(current_width, min_width, max_width, content_width)
  local min = math.max(content_width, min_width or 0)
  return math.max(current_width, math.min(max_width or min, min))
end

---@generic C: table
---@param idx integer
---@param grid nui_t_list<nui_t_list<C>>
---@param kind _nui_table_header_kind
---@return nui_t_list<C> header_row
local function get_header_row_at(idx, grid, kind)
  local row = grid[idx]
  if not row then
    row = { len = 0 }
    grid[idx] = row
    grid.len = math.max(grid.len, kind * idx)
  end
  return row
end

---@generic C: table
---@param kind _nui_table_header_kind
---@param columns (NuiTable.ColumnDef|{ depth: integer })[]
---@param grid nui_t_list<nui_t_list<C>>
---@param max_depth integer
local function prepare_header_grid(kind, columns, grid, max_depth)
  local columns_len = #columns
  for column_idx = 1, columns_len do
    local column = columns[column_idx]

    local row_idx = kind + kind * column.depth
    local row = get_header_row_at(row_idx, grid, kind)

    local content = kind == 1 and column.header or kind == -1 and column.footer or Text("")
    if type(content) == "function" then
      --[[@cast column NuiTable.Column]]
      content = content({ column = column })
      --[[@cast content -function]]
    end
    if type(content) ~= "table" then
      content = Text(content --[[@as string]])
      --[[@cast content -string]]
    end

    column.width = get_col_width(column.width, column.min_width, column.max_width, content:width())

    local cell = {
      column = column,
      content = content,
      col_span = 1,
      row_span = 1,
      ridx = 1,
    }

    row.len = row.len + 1
    row[row.len] = cell

    if column.columns then
      cell.col_span = #column.columns
      prepare_header_grid(kind, column.columns, grid, max_depth)
    else
      cell.row_span = max_depth - column.depth
      for i = 1, cell.row_span - 1 do
        local span_row = get_header_row_at(row_idx + i * kind, grid, kind)
        span_row.len = span_row.len + 1
        span_row[span_row.len] = vim.tbl_extend("keep", { ridx = i + 1 }, cell)
      end
    end
  end
end

---@param cell NuiTable.Cell
---@return NuiText|NuiLine
local function prepare_cell_content(cell)
  local column = cell.column --[[@as NuiTable.ColumnDef|NuiTable.Column]]
  local content = column.cell and column.cell(cell) or cell.get_value()
  if type(content) ~= "table" then
    content = Text(tostring(content))
  end
  return content
end

---@return nui_t_list<NuiTable.Cell[]> data_grid
---@return nui_t_list<nui_t_list<table>> header_grid
function Table:_prepare_grid()
  ---@type nui_t_list<NuiTable.Cell[]>
  local data_grid = {}

  ---@type nui_t_list<nui_t_list<table>>
  local header_grid = { len = 0 }
  if self._.has_header then
    prepare_header_grid(1, self._.headers, header_grid, self._.headers.depth)
  end

  local rows = self._.data
  local rows_len = #rows

  local columns = self._.columns
  local columns_len = #columns

  for row_idx = 1, rows_len do
    local data = rows[row_idx]

    data_grid[row_idx] = {}

    ---@type NuiTable.Row
    local row = {
      id = tostring(row_idx),
      index = row_idx,
      original = data,
    }

    for column_idx = 1, columns_len do
      local column = columns[column_idx]

      ---@type NuiTable.Cell
      local cell = {
        row = row,
        column = column,
        get_value = function()
          return column.accessor_fn(row.original, row.index)
        end,
      }

      cell.content = prepare_cell_content(cell)

      column.width = get_col_width(column.width, column.min_width, column.max_width, cell.content:width())

      data_grid[row_idx][column_idx] = cell
    end
  end

  if self._.has_footer then
    prepare_header_grid(-1, self._.headers, header_grid, self._.headers.depth)
  end

  for idx = -header_grid.len, header_grid.len do
    for _, th in ipairs(header_grid[idx] or {}) do
      local column = th.column
      if column.columns then
        column.width = 0
        for i = 1, th.col_span do
          column.width = column.width + column.columns[i].width
        end
        column.width = column.width + th.col_span - 1
      end
    end
  end

  data_grid.len = rows_len

  return data_grid, header_grid
end

---@param line NuiLine
---@param content NuiLine|NuiText
---@param width integer
---@param align nui_t_text_align
local function append_content(line, content, width, align)
  if content._texts then
    --[[@cast content NuiLine]]
    _.truncate_nui_line(content, width)
  else
    --[[@cast content NuiText]]
    _.truncate_nui_text(content, width)
  end
  local left_gap_width, right_gap_width = _.calculate_gap_width(align, width, content:width())
  if left_gap_width > 0 then
    line:append(Text(string.rep(" ", left_gap_width)))
  end
  line:append(content)
  if right_gap_width > 0 then
    line:append(Text(string.rep(" ", right_gap_width)))
  end
  return line
end

---@param kind _nui_table_header_kind
---@param lines nui_t_list<NuiLine>
---@param grid nui_t_list<nui_t_list<table>>
function Table:_prepare_header_lines(kind, lines, grid)
  local line_idx = lines.len

  local start_idx, end_idx = 1, grid.len
  if kind == -1 then
    start_idx, end_idx = -grid.len, -1
  end

  local border = self._.border

  for row_idx = start_idx, end_idx do
    local row = grid[row_idx]
    if not row then
      break
    end

    local inner_border_line = Line()
    local data_line = Line()
    local outer_border_line = Line()

    outer_border_line:append(kind == 1 and border.down_right or border.up_right)

    data_line:append(border.ver)

    local cells_len = #row
    for cell_idx = 1, cells_len do
      local prev_cell = row[cell_idx - 1]
      local cell = row[cell_idx]
      local next_cell = row[cell_idx + 1]

      if cell.row_span == cell.ridx then
        if cell_idx == 1 or (prev_cell and prev_cell.ridx ~= prev_cell.row_span) then
          inner_border_line:append(border.ver_right)
        else
          inner_border_line:append(border.ver_hor)
        end
      elseif next_cell then
        inner_border_line:append(border.ver)
      else
        inner_border_line:append(border.ver_left)
      end

      local column = cell.column

      if column.columns then
        for sc_idx = 1, cell.col_span do
          local sub_column = column.columns[sc_idx]
          inner_border_line:append(string.rep(border.hor, sub_column.width))
          if sc_idx ~= cell.col_span then
            inner_border_line:append(kind == 1 and border.down_hor or border.up_hor)
          end
        end
      else
        if cell.ridx == cell.row_span then
          inner_border_line:append(string.rep(border.hor, column.width))
        else
          inner_border_line:append(string.rep(" ", column.width))
        end
      end

      if cell.ridx == cell.row_span then
        append_content(data_line, cell.content, column.width, column.align)
      else
        append_content(data_line, Text(""), column.width, column.align)
      end
      data_line:append(border.ver)

      outer_border_line:append(string.rep(border.hor, column.width))
      outer_border_line:append(kind == 1 and border.down_hor or border.up_hor)
    end

    local last_cell = row[cells_len]
    if last_cell.ridx == last_cell.row_span then
      inner_border_line:append(border.ver_left)
    else
      inner_border_line:append(border.ver)
    end

    outer_border_line._texts[#outer_border_line._texts]:set(kind == 1 and border.down_left or border.up_left)

    if kind == -1 then
      line_idx = line_idx + 1
      lines[line_idx] = inner_border_line
    elseif row_idx == 1 then
      line_idx = line_idx + 1
      lines[line_idx] = outer_border_line
    end
    line_idx = line_idx + 1
    lines[line_idx] = data_line
    if kind == 1 then
      line_idx = line_idx + 1
      lines[line_idx] = inner_border_line
    elseif row_idx == -1 then
      line_idx = line_idx + 1
      lines[line_idx] = outer_border_line
    end
  end

  lines.len = line_idx
end

---@param linenr_start? integer start line number (1-indexed)
function Table:render(linenr_start)
  if #self._.columns == 0 then
    return
  end

  linenr_start = math.max(1, linenr_start or self._.linenr[1] or 1)
  local prev_linenr = { self._.linenr[1], self._.linenr[2] }

  local data_grid, header_grid = self:_prepare_grid()

  self._.data_grid = data_grid

  local line_idx = 0
  ---@type nui_t_list<NuiLine>
  local lines = { len = line_idx }

  self:_prepare_header_lines(1, lines, header_grid)
  line_idx = lines.len

  local border = self._.border

  local rows_len = data_grid.len

  if line_idx == 0 and rows_len > 0 then
    local columns = self._.columns
    local columns_len = #columns

    local top_border_line = Line()

    top_border_line:append(border.down_right)
    for column_idx = 1, columns_len do
      local column = columns[column_idx]
      top_border_line:append(string.rep(border.hor, column.width))
      if column_idx ~= columns_len then
        top_border_line:append(border.down_hor)
      end
    end
    top_border_line:append(border.down_left)

    line_idx = line_idx + 1
    lines[line_idx] = top_border_line
  end

  local data_linenrs = self._.data_linenrs

  for row_idx = 1, rows_len do
    local char_idx = 0

    local is_last_line = row_idx == rows_len
    local bottom_border_mid = is_last_line and border.up_hor or border.ver_hor

    local row = data_grid[row_idx]

    local data_line = Line()
    local bottom_border_line = Line()

    local data_linenr = line_idx + linenr_start
    data_line:append(border.ver)
    char_idx = char_idx + 1

    bottom_border_line:append(is_last_line and border.up_right or border.ver_right)

    local cells_len = #row
    for cell_idx = 1, cells_len do
      local cell = row[cell_idx]

      local column = cell.column

      append_content(data_line, cell.content, column.width, column.align)
      data_line:append(border.ver)
      cell.range = { data_linenr, char_idx, data_linenr, char_idx + column.width }
      char_idx = cell.range[4] + 1

      bottom_border_line:append(string.rep(border.hor, column.width))
      bottom_border_line:append(bottom_border_mid)
    end
    bottom_border_line._texts[#bottom_border_line._texts]:set(is_last_line and border.up_left or border.ver_left)

    line_idx = line_idx + 1
    lines[line_idx] = data_line

    data_linenrs[row_idx] = data_linenr

    if not is_last_line or not header_grid[-1] then
      line_idx = line_idx + 1
      lines[line_idx] = bottom_border_line
    end
  end

  lines.len = line_idx
  self:_prepare_header_lines(-1, lines, header_grid)
  line_idx = lines.len
  lines.len = nil

  _.set_buf_options(self.bufnr, { modifiable = true, readonly = false })

  _.clear_namespace(self.bufnr, self.ns_id)

  -- if linenr_start was shifted downwards,
  -- clear the previously rendered lines above.
  _.clear_lines(
    self.bufnr,
    math.min(linenr_start, prev_linenr[1] or linenr_start),
    prev_linenr[1] and linenr_start - 1 or 0
  )

  -- for initial render, start inserting in a single line.
  -- for subsequent renders, replace the lines from previous render.
  _.render_lines(lines, self.bufnr, self.ns_id, linenr_start, prev_linenr[1] and prev_linenr[2] or linenr_start)

  _.set_buf_options(self.bufnr, { modifiable = false, readonly = true })

  self._.linenr[1], self._.linenr[2] = linenr_start, line_idx + linenr_start - 1
end

---@param position? {[1]: integer, [2]: integer}
function Table:get_cell(position)
  local pos = vim.fn.getcharpos(".") --[[@as integer[] ]]
  local line, char = pos[2], pos[3]

  local row_idx = 0
  for idx, linenr in ipairs(self._.data_linenrs) do
    if linenr == line then
      row_idx = idx
      break
    elseif linenr > line then
      break
    end
  end
  row_idx = row_idx + (position and position[1] or 0)

  local row = self._.data_grid[row_idx]
  if not row then
    return
  end

  local cell_idx = 0
  for idx, cell in ipairs(row) do
    local range = cell.range
    if range[2] < char and char <= range[4] then
      cell_idx = idx
    end
  end
  cell_idx = cell_idx + (position and position[2] or 0)

  return row[cell_idx]
end

function Table:refresh_cell(cell)
  local column = cell.column

  local range = cell.range
  local byte_range = _.char_to_byte_range(self.bufnr, range[1], range[2], range[4])

  local content = prepare_cell_content(cell)
  if cell.content ~= content then
    cell.content = content

    local extmarks = vim.api.nvim_buf_get_extmarks(
      self.bufnr,
      self.ns_id,
      { range[1] - 1, byte_range[1] },
      { range[3] - 1, byte_range[2] - 1 },
      {}
    )
    for _, extmark in ipairs(extmarks) do
      vim.api.nvim_buf_del_extmark(self.bufnr, self.ns_id, extmark[1])
    end
  end

  _.set_buf_options(self.bufnr, { modifiable = true, readonly = false })
  _.render_lines(
    { append_content(Line(), content, column.width, column.align) },
    self.bufnr,
    self.ns_id,
    range[1],
    range[3],
    byte_range[1],
    byte_range[2]
  )
  _.set_buf_options(self.bufnr, { modifiable = false, readonly = true })
end

---@alias NuiTable.constructor fun(options: nui_table_options): NuiTable
---@type NuiTable|NuiTable.constructor
local NuiTable = Table

return NuiTable
