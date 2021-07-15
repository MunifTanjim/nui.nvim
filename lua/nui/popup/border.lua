local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type

local index_name = {
  "top_left",
  "top",
  "top_right",
  "right",
  "bottom_right",
  "bottom",
  "bottom_left",
  "left",
}

local function to_border_map(border)
  if not is_type("list", border) then
    error("invalid data")
  end

  -- fillup all 8 characters
  local count = vim.tbl_count(border)
  if count < 8 then
    for i = count + 1, 8 do
      local fallback_index = i % count
      border[i] = border[fallback_index == 0 and count or fallback_index]
    end
  end

  local named_border = {}

  for index, name in ipairs(index_name) do
    named_border[name] = border[index]
  end

  return named_border
end

local function to_border_list(named_border)
  if not is_type("map", named_border) then
    error("invalid data")
  end

  local border = {}

  for index, name in ipairs(index_name) do
    if is_type(named_border[name], "nil") then
      error(string.format("missing named border: %s", name))
    end

    border[index] = named_border[name]
  end

  return border
end

---@param edge "'top'" | "'bottom'"
---@param text nil | string
---@param alignment nil | "'left'" | "'center'" | "'right'"
local function calculate_buf_edge_line(border, edge, text, alignment)
  local char, size = border.char, border.size
  local content = defaults(text, "")
  local align = defaults(alignment, "center")

  local max_length = size.width - 2
  if #content > max_length then
    content = string.sub(content, 1, max_length - 1) .. "…"
  end
  local gap_length = max_length - #content

  local left = ""
  local right = ""

  if align == "left" then
    right = string.rep(char[edge], gap_length)
  elseif align == "center" then
    left = string.rep(char[edge], math.floor(gap_length / 2))
    right = string.rep(char[edge], math.ceil(gap_length / 2))
  elseif align == "right" then
    left = string.rep(char[edge], gap_length)
  end

  return char[edge .. "_left"] .. left .. content .. right .. char[edge .. "_right"]
end

local function calculate_buf_lines(border)
  local char, size, text = border.char, border.size, border.text

  local middle_line = char.left ..  string.rep(" ", size.width - 2) .. char.right

  local lines = {}

  table.insert(lines, calculate_buf_edge_line(border, "top", text.top, text.top_align))
  for _ = 1, size.height - 2 do
    table.insert(lines, middle_line)
  end
  table.insert(lines, calculate_buf_edge_line(border, "bottom", text.bottom, text.bottom_align))

  return lines
end

local styles = {
  double  = to_border_map({ "╔", "═", "╗", "║", "╝", "═", "╚", "║" }),
  none    = "none",
  rounded = to_border_map({ "╭", "─", "╮", "│", "╯", "─", "╰", "│" }),
  shadow  = "shadow",
  single  = to_border_map({ "┌", "─", "┐", "│", "┘", "─", "└", "│" }),
  solid   = to_border_map({ "▛", "▀", "▜", "▐", "▟", "▄", "▙", "▌" }),
}

local Border = {}

function Border:new(popup, opts)
  if is_type("string", opts) then
    opts = {
      style = opts
    }
  end

  local border = {
    popup = popup,
    type = "simple",
    style = defaults(opts.style, "none"),
    text = defaults(opts.text, {}),
    highlight = defaults(opts.highlight, "FloatBorder"),
  }

  setmetatable(border, self)
  self.__index = self

  local style = border.style

  if is_type("list", style) then
    border.char = to_border_map(style)
  elseif is_type("string", style) then
    if not styles[style] then
      error("invalid border style name")
    end

    border.char = styles[style]
  end

  if is_type("string", border.char) then
    return border
  end

  if border.text.top or border.text.bottom or border.popup.padding then
    border.type = "complex"
  end

  if border.type == "complex" then
    local padding = defaults(border.popup.padding, {})

    border.size = vim.deepcopy(border.popup.size)
    border.position = vim.deepcopy(border.popup.position)

    if border.text.top or border.char.top ~= "" then
      border.size.height = border.size.height + 1
      border.popup.position.row = border.popup.position.row + 1

      if padding.top then
        border.popup.size.height = border.popup.size.height - padding.top
        border.popup.position.row = border.popup.position.row + padding.top
      end
    end

    if border.text.bottom or border.char.bottom ~= "" then
      border.size.height = border.size.height + 1

      if padding.bottom then
        border.popup.size.height = border.popup.size.height - padding.bottom
      end
    end

    if border.char.left ~= "" then
      border.size.width = border.size.width + 1
      border.popup.position.col = border.popup.position.col + 1

      if padding.left then
        border.popup.size.width = border.popup.size.width - padding.left
        border.popup.position.col = border.popup.position.col + padding.left
      end
    end

    if border.char.right ~= "" then
      border.size.width = border.size.width + 1

      if padding.right then
        border.popup.size.width = border.popup.size.width - padding.right
      end
    end

    border.buf_lines = calculate_buf_lines(border)
  end

  return border
end

function Border:mount()
  if self.type == "simple" then
    return
  end

  local size, position = self.size, self.position

  self.bufnr = vim.api.nvim_create_buf(false, true)
  assert(self.bufnr, "failed to create border buffer")

  vim.api.nvim_buf_set_lines(self.bufnr, 0, size.height - 2, false, self.buf_lines)

  self.winid = vim.api.nvim_open_win(self.bufnr, false, {
    style = "minimal",
    relative = self.popup.config.relative,
    border = "none",
    focusable = false,
    width = size.width,
    height = size.height,
    bufpos = self.popup.config.bufpos,
    row = position.row,
    col = position.col,
    zindex = self.popup.config.zindex - 1,
  })
  assert(self.winid, "failed to create border window")

  if self.popup.options.winhighlight then
    vim.api.nvim_win_set_option(self.winid, 'winhighlight', self.popup.options.winhighlight)
  end
end

function Border:unmount()
  if self.type == "simple" then
    return
  end

  if vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end

  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end
end

---@param edge "'top'" | "'bottom'"
---@param text nil | string
---@param align nil | "'left'" | "'center'" | "'right'"
function Border:set_text(edge, text, align)
  align = defaults(align, self.text[edge .. "_align"])
  local line = calculate_buf_edge_line(self, edge, text, align)

  if edge == "top" then
    vim.api.nvim_buf_set_lines(self.bufnr, 0, 1, false, { line })
  elseif edge == "bottom" then
    vim.api.nvim_buf_set_lines(self.bufnr, -2, -1, false, { line })
  end
end

function Border:get()
  if self.type == "simple" then
    if is_type("string", self.char) then
      return self.char
    end

    for position, item in pairs(self.char) do
      self.char[position] = { item, self.highlight }
    end

    return to_border_list(self.char)
  end

  return nil
end

return Border
