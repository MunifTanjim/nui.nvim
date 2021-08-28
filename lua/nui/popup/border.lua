local _utils = require("nui.utils")._
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type

---@param str string
---@return number
local function strwidth(str)
  return vim.api.nvim_strwidth(str)
end

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

local function parse_padding(padding)
  if not padding then
    return nil
  end

  if is_type("map", padding) then
    return padding
  end

  local map = {}
  map.top = defaults(padding[1], 0)
  map.right = defaults(padding[2], map.top)
  map.bottom = defaults(padding[3], map.top)
  map.left = defaults(padding[4], map.right)
  return map
end

---@param edge "'top'" | "'bottom'"
---@param text nil | string
---@param alignment nil | "'left'" | "'center'" | "'right'"
---@return string
local function calculate_buf_edge_line(props, edge, text, alignment)
  local char, size = props.char, props.size

  local left_char = char[edge .. "_left"]
  local mid_char = char[edge]
  local right_char = char[edge .. "_right"]

  if left_char == "" then
    left_char = mid_char == "" and char["left"] or mid_char
  end

  if right_char == "" then
    right_char = mid_char == "" and char["right"] or mid_char
  end

  local max_length = size.width - strwidth(left_char .. right_char)

  local content = defaults(text, "")
  local align = defaults(alignment, "center")

  if mid_char == "" then
    content = string.rep(" ", max_length)
  else
    content = _utils.truncate_text(content, max_length)
  end

  return left_char .. _utils.align_text(content, align, max_length, mid_char) .. right_char
end

---@return nil | string[]
local function calculate_buf_lines(props)
  local char, size, text = props.char, props.size, defaults(props.text, {})

  if is_type("string", char) then
    return nil
  end

  local gap_length = size.width - strwidth(char.left .. char.right)
  local middle_line = char.left .. string.rep(" ", gap_length) .. char.right

  local lines = {}

  table.insert(lines, calculate_buf_edge_line(props, "top", text.top, text.top_align))
  for _ = 1, size.height - 2 do
    table.insert(lines, middle_line)
  end
  table.insert(lines, calculate_buf_edge_line(props, "bottom", text.bottom, text.bottom_align))

  return lines
end

local styles = {
  double = to_border_map({ "╔", "═", "╗", "║", "╝", "═", "╚", "║" }),
  none = "none",
  rounded = to_border_map({ "╭", "─", "╮", "│", "╯", "─", "╰", "│" }),
  shadow = "shadow",
  single = to_border_map({ "┌", "─", "┐", "│", "┘", "─", "└", "│" }),
  solid = to_border_map({ "▛", "▀", "▜", "▐", "▟", "▄", "▙", "▌" }),
}

local function calculate_size(border)
  local size = vim.deepcopy(border.popup.popup_props.size)

  local char = border.border_props.char

  if is_type("map", char) then
    if char.top ~= "" then
      size.height = size.height + 1
    end

    if char.bottom ~= "" then
      size.height = size.height + 1
    end

    if char.left ~= "" then
      size.width = size.width + 1
    end

    if char.right ~= "" then
      size.width = size.width + 1
    end
  end

  local padding = border.border_props.padding

  if padding then
    if padding.top then
      size.height = size.height + padding.top
    end

    if padding.bottom then
      size.height = size.height + padding.bottom
    end

    if padding.left then
      size.width = size.width + padding.left
    end

    if padding.right then
      size.width = size.width + padding.right
    end
  end

  return size
end

local function calculate_position(border)
  local popup = border.popup

  local position = vim.deepcopy(popup.popup_props.position)

  local char = border.border_props.char

  if is_type("map", char) then
    if char.top ~= "" then
      popup.popup_props.position.row = popup.popup_props.position.row + 1
    end

    if char.left ~= "" then
      popup.popup_props.position.col = popup.popup_props.position.col + 1
    end
  end

  local padding = border.border_props.padding

  if padding then
    if padding.top then
      popup.popup_props.position.row = popup.popup_props.position.row + padding.top
    end

    if padding.left then
      popup.popup_props.position.col = popup.popup_props.position.col + padding.left
    end
  end

  return position
end

local function init(class, popup, options)
  local self = setmetatable({}, class)

  self.popup = popup

  if is_type("string", options) then
    options = {
      style = options,
    }
  end

  self.border_props = {
    type = "simple",
    style = defaults(options.style, "none"),
    padding = parse_padding(options.padding),
    text = options.text,
  }

  local props = self.border_props

  local style = props.style

  if is_type("list", style) then
    props.char = to_border_map(style)
  elseif is_type("string", style) then
    if not styles[style] then
      error("invalid border style name")
    end

    props.char = vim.deepcopy(styles[style])
  end

  local is_borderless = is_type("string", props.char)

  if is_borderless then
    if props.text then
      error("text not supported for style:" .. props.char)
    end
  end

  if props.text or props.padding then
    props.type = "complex"
  end

  if props.type == "simple" then
    return self
  end

  if props.type == "complex" then
    props.size = calculate_size(self)
    props.position = calculate_position(self)

    props.buf_lines = calculate_buf_lines(props)

    self.win_config = {
      style = "minimal",
      relative = popup.win_config.relative,
      win = popup.win_config.win,
      border = "none",
      focusable = false,
      width = props.size.width,
      height = props.size.height,
      bufpos = popup.win_config.bufpos,
      row = props.position.row,
      col = props.position.col,
      zindex = self.popup.win_config.zindex - 1,
    }
  end

  props.highlight = defaults(options.highlight, "FloatBorder")
  if props.type == "complex" and not string.match(props.highlight, ":") then
    props.highlight = "Normal:" .. props.highlight
  end

  return self
end

local Border = {
  super = nil,
  name = "Border",
}

function Border:init(popup, options)
  return init(self, popup, options)
end

function Border:mount()
  local popup = self.popup

  if not popup.popup_state.loading or popup.popup_state.mounted then
    return
  end

  local props = self.border_props

  if props.type == "simple" then
    return
  end

  local size = props.size

  self.bufnr = vim.api.nvim_create_buf(false, true)
  assert(self.bufnr, "failed to create border buffer")

  if props.buf_lines then
    vim.api.nvim_buf_set_lines(self.bufnr, 0, size.height, false, props.buf_lines)
  end

  self.winid = vim.api.nvim_open_win(self.bufnr, false, self.win_config)
  assert(self.winid, "failed to create border window")

  vim.api.nvim_win_set_option(self.winid, "winhighlight", self.border_props.highlight)
end

function Border:unmount()
  local popup = self.popup

  if not popup.popup_state.loading or not popup.popup_state.mounted then
    return
  end

  local props = self.border_props

  if props.type == "simple" then
    return
  end

  if self.bufnr then
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
    self.bufnr = nil
  end

  if self.winid then
    if vim.api.nvim_win_is_valid(self.winid) then
      vim.api.nvim_win_close(self.winid, true)
    end
    self.winid = nil
  end
end

function Border:resize()
  local props = self.border_props

  props.size = calculate_size(self)

  props.buf_lines = calculate_buf_lines(props)

  self.win_config.width = props.size.width
  self.win_config.height = props.size.height

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, {
      width = props.size.width,
      height = props.size.height,
    })
  end

  if self.bufnr then
    if self.border_props.buf_lines then
      vim.api.nvim_buf_set_lines(self.bufnr, 0, props.size.height, false, props.buf_lines)
    end
  end
end

function Border:reposition()
  local props = self.border_props

  if props.type == "complex" then
    props.position = calculate_position(self)
  end

  self.win_config.relative = self.popup.win_config.relative
  self.win_config.win = self.popup.win_config.win
  self.win_config.bufpos = self.popup.win_config.bufpos

  self.win_config.row = props.position.row
  self.win_config.col = props.position.col

  if self.winid then
    vim.api.nvim_win_set_config(
      self.winid,
      vim.tbl_extend("force", self.win_config, {
        row = props.position.row,
        col = props.position.col,
      })
    )
  end
end

---@param edge "'top'" | "'bottom'"
---@param text nil | string
---@param align nil | "'left'" | "'center'" | "'right'"
function Border:set_text(edge, text, align)
  local props = self.border_props

  if not props.buf_lines or not props.text then
    return
  end

  props.text[edge] = text
  props.text[edge .. "_align"] = defaults(align, props.text[edge .. "_align"])

  local line = calculate_buf_edge_line(props, edge, props.text[edge], props.text[edge .. "_align"])

  if edge == "top" then
    props.buf_lines[1] = line
    vim.api.nvim_buf_set_lines(self.bufnr, 0, 1, false, { line })
  elseif edge == "bottom" then
    props.buf_lines[#props.buf_lines] = line
    vim.api.nvim_buf_set_lines(self.bufnr, props.size.height - 1, props.size.height, true, { line })
  end
end

function Border:get()
  local props = self.border_props

  if props.type == "simple" then
    if is_type("string", props.char) then
      return props.char
    end

    local char = {}

    for position, item in pairs(props.char) do
      char[position] = { item, props.highlight }
    end

    return to_border_list(char)
  end

  return nil
end

local BorderClass = setmetatable({
  __index = Border,
}, {
  __call = init,
  __index = Border,
})

return BorderClass
