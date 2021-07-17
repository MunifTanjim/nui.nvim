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
local function calculate_buf_edge_line(props, edge, text, alignment)
  local char, size = props.char, props.size
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

local function calculate_buf_lines(props)
  local char, size, text = props.char, props.size, props.text

  local middle_line = char.left ..  string.rep(" ", size.width - 2) .. char.right

  local lines = {}

  table.insert(lines, calculate_buf_edge_line(props, "top", text.top, text.top_align))
  for _ = 1, size.height - 2 do
    table.insert(lines, middle_line)
  end
  table.insert(lines, calculate_buf_edge_line(props, "bottom", text.bottom, text.bottom_align))

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

local function init(class, popup, options)
  local self = setmetatable({}, class)

  self.popup = popup

  if is_type("string", options) then
    options = {
      style = options
    }
  end

  self.border_props  = {
    type = "simple",
    style = defaults(options.style, "none"),
    text = defaults(options.text, {}),
    highlight = defaults(options.highlight, "FloatBorder"),
  }

  local props = self.border_props

  local style = props.style

  if is_type("list", style) then
    props.char = to_border_map(style)
  elseif is_type("string", style) then
    if not styles[style] then
      error("invalid border style name")
    end

    props.char = styles[style]
  end

  if is_type("string", props.char) then
    return self
  end

  if props.text.top or props.text.bottom or popup.popup_props.padding then
    props.type = "complex"
  end

  if props.type == "complex" then
    local padding = defaults(popup.popup_props.padding, {})

    props.size = vim.deepcopy(popup.popup_props.size)
    props.position = vim.deepcopy(popup.popup_props.position)

    if props.text.top or props.char.top ~= "" then
      props.size.height = props.size.height + 1
      popup.popup_props.position.row = popup.popup_props.position.row + 1

      if padding.top then
        popup.popup_props.size.height = popup.popup_props.size.height - padding.top
        popup.popup_props.position.row = popup.popup_props.position.row + padding.top
      end
    end

    if props.text.bottom or props.char.bottom ~= "" then
      props.size.height = props.size.height + 1

      if padding.bottom then
        popup.popup_props.size.height = popup.popup_props.size.height - padding.bottom
      end
    end

    if props.char.left ~= "" then
      props.size.width = props.size.width + 1
      popup.popup_props.position.col = popup.popup_props.position.col + 1

      if padding.left then
        popup.popup_props.size.width = popup.popup_props.size.width - padding.left
        popup.popup_props.position.col = popup.popup_props.position.col + padding.left
      end
    end

    if props.char.right ~= "" then
      props.size.width = props.size.width + 1

      if padding.right then
        popup.popup_props.size.width = popup.popup_props.size.width - padding.right
      end
    end

    props.buf_lines = calculate_buf_lines(props)
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
  local props = self.border_props

  if props.type == "simple" then
    return
  end

  local size, position = props.size, props.position

  self.bufnr = vim.api.nvim_create_buf(false, true)
  assert(self.bufnr, "failed to create border buffer")

  vim.api.nvim_buf_set_lines(self.bufnr, 0, size.height - 2, false, props.buf_lines)

  self.winid = vim.api.nvim_open_win(self.bufnr, false, {
    style = "minimal",
    relative = self.popup.win_config.relative,
    border = "none",
    focusable = false,
    width = size.width,
    height = size.height,
    bufpos = self.popup.win_config.bufpos,
    row = position.row,
    col = position.col,
    zindex = self.popup.win_config.zindex - 1,
  })
  assert(self.winid, "failed to create border window")

  if self.popup.win_options.winhighlight then
    vim.api.nvim_win_set_option(self.winid, 'winhighlight', self.popup.win_options.winhighlight)
  end
end

function Border:unmount()
  local props = self.border_props

  if props.type == "simple" then
    return
  end

  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end

  if vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end
end

---@param edge "'top'" | "'bottom'"
---@param text nil | string
---@param align nil | "'left'" | "'center'" | "'right'"
function Border:set_text(edge, text, align)
  local props = self.border_props

  align = defaults(align, props.text[edge .. "_align"])
  local line = calculate_buf_edge_line(props, edge, text, align)

  if edge == "top" then
    vim.api.nvim_buf_set_lines(self.bufnr, 0, 1, false, { line })
  elseif edge == "bottom" then
    vim.api.nvim_buf_set_lines(self.bufnr, -2, -1, false, { line })
  end
end

function Border:get()
  local props = self.border_props

  if props.type == "simple" then
    if is_type("string", props.char) then
      return props.char
    end

    for position, item in pairs(props.char) do
      props.char[position] = { item, props.highlight }
    end

    return to_border_list(props.char)
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
