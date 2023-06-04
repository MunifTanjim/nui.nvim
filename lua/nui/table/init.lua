local Object = require("nui.object")
local Text = require("nui.text")
local Line = require("nui.line")
local utils = require("nui.utils")
local defaults = require("nui.utils").defaults

local _ = utils._
local is_type = utils.is_type

-- luacheck: push no max comment line length
---@alias nui_table_border_char_name 'down_right'|'hor'|'down_hor'|'down_left'|'ver'|'ver_left'|'ver_hor'|'ver_left'|'up_right'|'up_hor'|'up_left'
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

local function prepare_columns(meta, columns, parent, depth)
  for _, col in ipairs(columns) do
    if col.header then
      meta.has_header = true
    end

    if col.footer then
      meta.has_footer = true
    end

    if not col.id then
      col.id = col.accessor_key or col.header
    end

    if not col.id then
      error("missing column id")
    end

    if col.accessor_key then
      col.accessor_fn = function(row)
        return row[col.accessor_key]
      end
    end

    col.depth = depth or 0
    col.parent = parent

    if parent and not col.header then
      col.header = col.id
      meta.has_header = true
    end

    if col.columns then
      prepare_columns(meta, col.columns, col, col.depth + 1)
    else
      table.insert(meta.columns, col)
    end

    if col.depth == 0 then
      table.insert(meta.headers, col)
    else
      meta.headers.depth = math.max(meta.headers.depth, col.depth + 1)
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
---@field cell? fun(info: NuiTable.Cell): string|NuiText|NuiLine
---@field columns? NuiTable.ColumnDef[]
---@field footer? string|NuiText|NuiLine|fun(info: { column: NuiTable.Column }): string|NuiText|NuiLine
---@field header? string|NuiText|NuiLine|fun(info: { column: NuiTable.Column }): string|NuiText|NuiLine
---@field id? string

---@class NuiTable.Column
---@field accessor_fn? fun(original_row: table, index: integer): string|NuiText|NuiLine
---@field accessor_key? string
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

---@class NuiTable
local Table = Object("NuiTable")

---@class nui_table_options
---@field bufnr integer
---@field ns_id integer|string
---@field columns NuiTable.ColumnDef[]
---@field data table[]

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
    }, defaults(options.buf_options, {})),
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

local function get_col_width(current_width, min_width, max_width, content_width)
  local min = math.max(content_width, min_width or 0)
  return math.max(current_width, math.min(max_width or min, min))
end

local function get_row_at(idx, grid, kind)
  local row = grid[idx]
  if not row then
    row = { len = 0 }
    grid[idx] = row
    grid.len = math.max(grid.len, kind * idx)
  end
  return row
end

local function prepare_header_grid(kind, columns, grid, max_depth)
  for _, column in ipairs(columns) do
    local row_idx = kind + kind * column.depth
    local row = get_row_at(row_idx, grid, kind)

    ---@type string|function|NuiText|NuiLine
    local content = kind == 1 and column.header or kind == -1 and column.footer or Text("")
    if is_type("function", content) then
      content = content({ column = column })
    end
    if not is_type("table", content) then
      content = Text(
        content --[[@as string]]
      )
    end

    --[[@cast content NuiText|NuiLine]]
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
        local span_row = get_row_at(row_idx + i * kind, grid, kind)
        span_row.len = span_row.len + 1
        span_row[span_row.len] = vim.tbl_extend("keep", { ridx = i + 1 }, cell)
      end
    end
  end
end

---@return NuiText|NuiLine
local function prepare_cell_content(cell)
  local column = cell.column
  ---@type string|NuiText|NuiLine
  local content = column.cell and column.cell(cell) or cell.get_value()
  if not is_type("table", content) then
    content = Text(tostring(content))
  end
  return content --[[@as NuiText|NuiLine]]
end

function Table:_prepare_grid()
  local grid = {}

  local header_grid = { len = 0 }
  if self._.has_header then
    prepare_header_grid(1, self._.headers, header_grid, self._.headers.depth)
  end

  local gr_idx = 0
  for ridx, data in ipairs(self._.data) do
    gr_idx = gr_idx + 1

    grid[gr_idx] = {}

    local row = { id = tostring(ridx), original = data, index = ridx }

    local gc_idx = 0
    for _, column in ipairs(self._.columns) do
      gc_idx = gc_idx + 1

      local cell = {
        row = row,
        column = column,
      }
      function cell.get_value()
        return column.accessor_fn(row.original, row.index)
      end

      cell.content = prepare_cell_content(cell)

      column.width = get_col_width(column.width, column.min_width, column.max_width, cell.content:width())

      grid[gr_idx][gc_idx] = cell
    end
  end

  if self._.has_footer then
    prepare_header_grid(-1, self._.headers, header_grid, self._.headers.depth)
  end

  for idx = -header_grid.len, header_grid.len do
    for _, item in ipairs(header_grid[idx] or {}) do
      local column = item.column
      if column.columns then
        column.width = 0
        for i = 1, item.col_span do
          column.width = column.width + column.columns[i].width
        end
        column.width = column.width + item.col_span - 1
      end
    end
  end

  return grid, header_grid
end

local function append_content(line, content, width, align)
  if content._texts then
    _.truncate_nui_line(content, width)
  else
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

    local row_len = #row
    for cell_idx = 1, row_len do
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

    local last_cell = row[row_len]
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

  local grid, header_grid = self:_prepare_grid()

  self._.grid = grid

  local border = self._.border

  local line_idx = 0
  local lines = {}

  lines.len = line_idx
  self:_prepare_header_lines(1, lines, header_grid)
  line_idx = lines.len

  if line_idx == 0 and #grid > 0 then
    local top_border_line = Line()

    top_border_line:append(border.down_right)
    for idx, column in ipairs(self._.columns) do
      top_border_line:append(string.rep(border.hor, column.width))
      if idx ~= #self._.columns then
        top_border_line:append(border.down_hor)
      end
    end
    top_border_line:append(border.down_left)

    line_idx = line_idx + 1
    lines[line_idx] = top_border_line
  end

  local data_linenrs = self._.data_linenrs

  local grid_len = #grid
  for row_idx = 1, grid_len do
    local char_idx = 0

    local is_last_line = row_idx == grid_len
    local bottom_border_mid = is_last_line and border.up_hor or border.ver_hor

    local row = grid[row_idx]

    local data_line = Line()
    local bottom_border_line = Line()

    local data_linenr = line_idx + linenr_start
    data_line:append(border.ver)
    char_idx = char_idx + 1

    bottom_border_line:append(is_last_line and border.up_right or border.ver_right)
    for _, cell in ipairs(row) do
      local column = cell.column

      append_content(data_line, cell.content, column.width, column.align)
      data_line:append(border.ver)
      cell._range = { data_linenr, char_idx, data_linenr, char_idx + column.width }
      char_idx = cell._range[4] + 1

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

function Table:get_cell()
  local pos = vim.fn.getcharpos(".")
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

  local row = self._.grid[row_idx]
  if not row then
    return
  end

  for _, cell in ipairs(row) do
    local range = cell._range
    if range[2] < char and char <= range[4] then
      return cell
    end
  end
end

function Table:refresh_cell(cell)
  local column = cell.column

  local range = cell._range
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
