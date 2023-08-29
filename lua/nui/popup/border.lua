---@diagnostic disable: invisible

local Object = require("nui.object")
local Line = require("nui.line")
local Text = require("nui.text")
local _ = require("nui.utils")._
local is_type = require("nui.utils").is_type

local has_nvim_0_5_1 = vim.fn.has("nvim-0.5.1") == 1

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

---@param border _nui_popup_border_style_list
---@return _nui_popup_border_style_map
local function to_border_map(border)
  local count = vim.tbl_count(border) --[[@as integer]]
  if count < 8 then
    -- fillup all 8 characters
    for i = count + 1, 8 do
      local fallback_index = i % count
      local char = border[fallback_index == 0 and count or fallback_index]
      if type(char) == "table" then
        char = char.content and Text(char) or vim.deepcopy(char)
      end
      border[i] = char
    end
  end

  ---@type _nui_popup_border_style_map
  local named_border = {}
  for index, name in ipairs(index_name) do
    named_border[name] = border[index]
  end
  return named_border
end

---@param char _nui_popup_border_style_map
---@return _nui_popup_border_internal_char
local function normalize_char_map(char)
  if not char or type(char) == "string" then
    return char
  end

  for position, item in pairs(char) do
    if type(item) == "string" then
      char[position] = Text(item, "FloatBorder")
    elseif not item.content then
      char[position] = Text(item[1], item[2] or "FloatBorder")
    elseif item.extmark then
      item.extmark.hl_group = item.extmark.hl_group or "FloatBorder"
    else
      item.extmark = { hl_group = "FloatBorder" }
    end
  end

  return char --[[@as _nui_popup_border_internal_char]]
end

---@param char? NuiText
---@return boolean
local function is_empty_char(char)
  return not char or 0 == char:width()
end

---@param text? _nui_popup_border_option_text_value
---@return nil|NuiLine|NuiText
local function normalize_border_text(text)
  if not text then
    return text
  end

  if type(text) == "string" then
    return Text(text, "FloatTitle")
  end

  if text.content then
    for _, text_chunk in ipairs(text._texts or { text }) do
      text_chunk.extmark = vim.tbl_deep_extend("keep", text_chunk.extmark or {}, {
        hl_group = "FloatTitle",
      })
    end
    return text --[[@as NuiLine|NuiText]]
  end

  local line = Line()
  for _, chunk in ipairs(text) do
    if type(chunk) == "string" then
      line:append(chunk, "FloatTitle")
    else
      line:append(chunk[1], chunk[2] or "FloatTitle")
    end
  end
  return line
end

---@param internal nui_popup_border_internal
---@param popup_winhighlight? string
---@return nil|string
local function calculate_winhighlight(internal, popup_winhighlight)
  if internal.type == "simple" then
    return
  end

  local winhl = popup_winhighlight

  -- @deprecated
  if internal.highlight then
    if not string.match(internal.highlight, ":") then
      internal.highlight = "FloatBorder:" .. internal.highlight
    end

    winhl = internal.highlight
    internal.highlight = nil
  end

  return winhl
end

---@param padding? nui_popup_border_option_padding
---@return nil|nui_popup_border_internal_padding
local function normalize_option_padding(padding)
  if not padding then
    return nil
  end

  if is_type("map", padding) then
    ---@cast padding _nui_popup_border_option_padding_map
    return padding
  end

  local map = {}

  ---@cast padding _nui_popup_border_option_padding_list
  map.top = padding[1] or 0
  map.right = padding[2] or map.top
  map.bottom = padding[3] or map.top
  map.left = padding[4] or map.right

  return map
end

---@param text? nui_popup_border_option_text
---@return nil|nui_popup_border_internal_text
local function normalize_option_text(text)
  if not text then
    return text
  end

  text.top = normalize_border_text(text.top)
  text.bottom = normalize_border_text(text.bottom)

  return text --[[@as nui_popup_border_internal_text]]
end

---@param edge 'top'|'bottom'
---@param text? NuiLine|NuiText
---@param align? nui_t_text_align
---@return NuiLine
local function calculate_buf_edge_line(internal, edge, text, align)
  local char, size = internal.char, internal.size

  local left_char = char[edge .. "_left"]
  local mid_char = char[edge]
  local right_char = char[edge .. "_right"]

  if left_char:content() == "" then
    left_char = Text(mid_char:content() == "" and char["left"] or mid_char)
  end

  if right_char:content() == "" then
    right_char = Text(mid_char:content() == "" and char["right"] or mid_char)
  end

  local max_width = size.width - left_char:width() - right_char:width()

  local content = Line()
  if mid_char:width() == 0 then
    content:append(string.rep(" ", max_width))
  else
    content:append(text or "")
  end

  _.truncate_nui_line(content, max_width)

  local left_gap_width, right_gap_width = _.calculate_gap_width(align or "center", max_width, content:width())

  local line = Line()

  line:append(left_char)

  if left_gap_width > 0 then
    line:append(Text(mid_char):set(string.rep(mid_char:content(), left_gap_width)))
  end

  line:append(content)

  if right_gap_width > 0 then
    line:append(Text(mid_char):set(string.rep(mid_char:content(), right_gap_width)))
  end

  line:append(right_char)

  return line
end

---@param internal nui_popup_border_internal
---@return nil|NuiLine[]
local function calculate_buf_lines(internal)
  local char, size, text = internal.char, internal.size, internal.text or {}

  if type(char) == "string" then
    return nil
  end

  local left_char, right_char = char.left, char.right

  local gap_length = size.width - left_char:width() - right_char:width()

  ---@type NuiLine[]
  local lines = {}

  table.insert(lines, calculate_buf_edge_line(internal, "top", text.top, text.top_align))
  for _ = 1, size.height - 2 do
    table.insert(
      lines,
      Line({
        Text(left_char),
        Text(string.rep(" ", gap_length)),
        Text(right_char),
      })
    )
  end
  table.insert(lines, calculate_buf_edge_line(internal, "bottom", text.bottom, text.bottom_align))

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

---@param style nui_popup_border_option_style
---@param prev_char_map? _nui_popup_border_internal_char
---@return _nui_popup_border_style_map
local function prepare_char_map(style, prev_char_map)
  if type(style) == "string" then
    if not styles[style] then
      error("invalid border style name")
    end

    ---@cast style _nui_popup_border_style_builtin
    return vim.deepcopy(styles[style])
  end

  if is_type("list", style) then
    ---@cast style _nui_popup_border_style_list
    return to_border_map(style)
  end

  ---@cast style _nui_popup_border_style_map
  return vim.tbl_extend("force", prev_char_map or {}, style)
end

---@param internal nui_popup_border_internal
---@return nui_popup_border_internal_size
local function calculate_size_delta(internal)
  ---@type nui_popup_border_internal_size
  local delta = {
    width = 0,
    height = 0,
  }

  local char = internal.char
  if type(char) == "table" then
    if not is_empty_char(char.top) then
      delta.height = delta.height + 1
    end

    if not is_empty_char(char.bottom) then
      delta.height = delta.height + 1
    end

    if not is_empty_char(char.left) then
      delta.width = delta.width + 1
    end

    if not is_empty_char(char.right) then
      delta.width = delta.width + 1
    end
  end

  local padding = internal.padding
  if padding then
    if padding.top then
      delta.height = delta.height + padding.top
    end

    if padding.bottom then
      delta.height = delta.height + padding.bottom
    end

    if padding.left then
      delta.width = delta.width + padding.left
    end

    if padding.right then
      delta.width = delta.width + padding.right
    end
  end

  return delta
end

---@param border NuiPopupBorder
---@return nui_popup_border_internal_size
local function calculate_size(border)
  ---@type nui_popup_border_internal_size
  local size = vim.deepcopy(border.popup._.size)

  size.width = size.width + border._.size_delta.width
  size.height = size.height + border._.size_delta.height

  return size
end

---@param border NuiPopupBorder
---@return nui_popup_border_internal_position
local function calculate_position(border)
  local position = vim.deepcopy(border.popup._.position)
  position.col = position.col - math.floor(border._.size_delta.width / 2 + 0.5)
  position.row = position.row - math.floor(border._.size_delta.height / 2 + 0.5)
  return position
end

local function adjust_popup_win_config(border)
  local internal = border._

  local popup_position = {
    row = 0,
    col = 0,
  }

  local char = internal.char

  if type(char) == "table" then
    if not is_empty_char(char.top) then
      popup_position.row = popup_position.row + 1
    end

    if not is_empty_char(char.left) then
      popup_position.col = popup_position.col + 1
    end
  end

  local padding = internal.padding

  if padding then
    if padding.top then
      popup_position.row = popup_position.row + padding.top
    end

    if padding.left then
      popup_position.col = popup_position.col + padding.left
    end
  end

  local popup = border.popup

  -- luacov: disable
  if not has_nvim_0_5_1 then
    popup.win_config.row = internal.position.row + popup_position.row
    popup.win_config.col = internal.position.col + popup_position.col
    return
  end
  -- luacov: enable

  -- relative to the border window
  popup.win_config.anchor = nil
  popup.win_config.relative = "win"
  popup.win_config.win = border.winid
  popup.win_config.bufpos = nil
  popup.win_config.row = popup_position.row
  popup.win_config.col = popup_position.col
end

--luacheck: push no max line length

---@alias nui_t_text_align 'left'|'center'|'right'

---@alias nui_popup_border_internal_type 'simple'|'complex'
---@alias nui_popup_border_internal_position table<'row'|'col', number>
---@alias nui_popup_border_internal_size table<'height'|'width', number>
---@alias nui_popup_border_internal_padding _nui_popup_border_option_padding_map
---@alias nui_popup_border_internal_text { top?: NuiLine|NuiText, top_align?: nui_t_text_align, bottom?: NuiLine|NuiText, bottom_align?: nui_t_text_align }
---@alias _nui_popup_border_internal_char table<_nui_popup_border_style_map_position, NuiText>

---@alias _nui_popup_border_option_padding_list table<1|2|3|4, integer>
---@alias _nui_popup_border_option_padding_map table<'top'|'right'|'bottom'|'left', integer>
---@alias nui_popup_border_option_padding _nui_popup_border_option_padding_list|_nui_popup_border_option_padding_map

---@alias _nui_popup_border_style_char_tuple table<1|2, string>
---@alias _nui_popup_border_style_char string|_nui_popup_border_style_char_tuple|NuiText
---@alias _nui_popup_border_style_builtin 'double'|'none'|'rounded'|'shadow'|'single'|'solid'
---@alias _nui_popup_border_style_list table<1|2|3|4|5|6|7|8, _nui_popup_border_style_char>
---@alias _nui_popup_border_style_map_position 'top_left'|'top'|'top_right'|'right'|'bottom_right'|'bottom'|'botom_left'|'left'
---@alias _nui_popup_border_style_map table<_nui_popup_border_style_map_position, _nui_popup_border_style_char>
---@alias nui_popup_border_option_style _nui_popup_border_style_builtin|_nui_popup_border_style_list|_nui_popup_border_style_map

---@alias _nui_popup_border_option_text_value string|NuiLine|NuiText|string[]|table<1|2, string>[]
---@alias nui_popup_border_option_text { top?: _nui_popup_border_option_text_value, top_align?: nui_t_text_align, bottom?: _nui_popup_border_option_text_value, bottom_align?: nui_t_text_align }

--luacheck: pop

---@class nui_popup_border_internal
---@field type nui_popup_border_internal_type
---@field style nui_popup_border_option_style
---@field char _nui_popup_border_internal_char
---@field padding? _nui_popup_border_option_padding_map
---@field position nui_popup_border_internal_position
---@field size nui_popup_border_internal_size
---@field size_delta nui_popup_border_internal_size
---@field text? nui_popup_border_internal_text
---@field lines? NuiLine[]
---@field winhighlight? string

---@class nui_popup_border_options
---@field padding? nui_popup_border_option_padding
---@field style? nui_popup_border_option_style
---@field text? nui_popup_border_option_text

---@class NuiPopupBorder
---@field bufnr integer
---@field private _ nui_popup_border_internal
---@field private popup NuiPopup
---@field win_config nui_popup_win_config
---@field winid number
local Border = Object("NuiPopupBorder")

---@param popup NuiPopup
---@param options nui_popup_border_options
function Border:init(popup, options)
  self.popup = popup

  self._ = {
    ---@deprecated
    highlight = options.highlight,
    padding = normalize_option_padding(options.padding),
    text = normalize_option_text(options.text),
  }

  local internal = self._

  if internal.text or internal.padding then
    internal.type = "complex"
  else
    internal.type = "simple"
  end

  self:set_style(options.style or "none")

  internal.winhighlight = calculate_winhighlight(internal, self.popup._.win_options.winhighlight)

  if internal.type == "simple" then
    return self
  end

  self:_buf_create()

  self.win_config = {
    style = "minimal",
    border = "none",
    focusable = false,
    zindex = self.popup.win_config.zindex - 1,
    anchor = self.popup.win_config.anchor,
  }

  if type(internal.char) == "string" then
    self.win_config.border = internal.char
  end
end

function Border:_open_window()
  if self.winid or not self.bufnr then
    return
  end

  self.win_config.noautocmd = true
  self.winid = vim.api.nvim_open_win(self.bufnr, false, self.win_config)
  self.win_config.noautocmd = nil
  assert(self.winid, "failed to create border window")

  if self._.winhighlight then
    vim.api.nvim_win_set_option(self.winid, "winhighlight", self._.winhighlight)
  end

  adjust_popup_win_config(self)

  vim.api.nvim_command("redraw")
end

function Border:_close_window()
  if not self.winid then
    return
  end

  if vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end

  self.winid = nil
end

function Border:_buf_create()
  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[self.bufnr].modifiable = true
    assert(self.bufnr, "failed to create border buffer")
  end
end

function Border:mount()
  local popup = self.popup

  if not popup._.loading or popup._.mounted then
    return
  end

  local internal = self._

  if internal.type == "simple" then
    return
  end

  self:_buf_create()

  if internal.lines then
    _.render_lines(internal.lines, self.bufnr, popup.ns_id, 1, #internal.lines)
  end

  self:_open_window()
end

function Border:unmount()
  local popup = self.popup

  if not popup._.loading or not popup._.mounted then
    return
  end

  local internal = self._

  if internal.type == "simple" then
    return
  end

  if self.bufnr then
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      _.clear_namespace(self.bufnr, self.popup.ns_id)
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
    self.bufnr = nil
  end

  self:_close_window()
end

function Border:_relayout()
  local internal = self._

  if internal.type ~= "complex" then
    return
  end

  if self.popup.win_config.anchor and self.popup.win_config.anchor ~= self.win_config.anchor then
    self.win_config.anchor = self.popup.win_config.anchor
    self.popup.win_config.anchor = nil
  end

  local position = self.popup._.position
  self.win_config.relative = position.relative
  self.win_config.win = position.relative == "win" and position.win or nil
  self.win_config.bufpos = position.bufpos

  internal.size = calculate_size(self)
  self.win_config.width = internal.size.width
  self.win_config.height = internal.size.height

  internal.position = calculate_position(self)
  self.win_config.row = internal.position.row
  self.win_config.col = internal.position.col

  internal.lines = calculate_buf_lines(internal)

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self.win_config)
  end

  if self.bufnr then
    if internal.lines then
      _.render_lines(internal.lines, self.bufnr, self.popup.ns_id, 1, #internal.lines)
    end
  end

  adjust_popup_win_config(self)

  vim.api.nvim_command("redraw")
end

---@param edge "'top'" | "'bottom'"
---@param text? nil|string|NuiLine|NuiText
---@param align? nil | "'left'" | "'center'" | "'right'"
function Border:set_text(edge, text, align)
  local internal = self._

  if not internal.lines or not internal.text then
    return
  end

  internal.text[edge] = normalize_border_text(text)
  internal.text[edge .. "_align"] = align or internal.text[edge .. "_align"]

  local line = calculate_buf_edge_line(
    internal,
    edge,
    internal.text[edge],
    internal.text[edge .. "_align"] --[[@as nui_t_text_align]]
  )

  local linenr = edge == "top" and 1 or #internal.lines

  internal.lines[linenr] = line
  line:render(self.bufnr, self.popup.ns_id, linenr)
end

---@param highlight string highlight group
function Border:set_highlight(highlight)
  local internal = self._

  local winhighlight_data = _.parse_winhighlight(self.popup._.win_options.winhighlight)
  winhighlight_data["FloatBorder"] = highlight
  self.popup._.win_options.winhighlight = _.serialize_winhighlight(winhighlight_data)
  if self.popup.winid then
    vim.api.nvim_win_set_option(self.popup.winid, "winhighlight", self.popup._.win_options.winhighlight)
  end

  internal.winhighlight = calculate_winhighlight(internal, self.popup._.win_options.winhighlight)
  if self.winid then
    vim.api.nvim_win_set_option(self.winid, "winhighlight", internal.winhighlight)
  end
end

---@param style nui_popup_border_option_style
function Border:set_style(style)
  local internal = self._

  internal.style = style

  local char = prepare_char_map(internal.style, internal.char)

  local is_borderless = type(char) == "string"
  if is_borderless then
    if not internal.char then -- initial
      if internal.text then
        error("text not supported for style:" .. char)
      end
    elseif internal.type == "complex" then -- subsequent
      error("cannot change from previous style to " .. char)
    end
  end

  internal.char = normalize_char_map(char)
  internal.size_delta = calculate_size_delta(internal)
end

---@param char_map _nui_popup_border_internal_char
---@return _nui_popup_border_style_char_tuple[]
local function to_tuple_list(char_map)
  ---@type _nui_popup_border_style_char_tuple[]
  local border = {}

  for index, name in ipairs(index_name) do
    if not char_map[name] then
      error(string.format("missing named border: %s", name))
    end

    local char = char_map[name]
    border[index] = { char:content(), char.extmark.hl_group }
  end

  return border
end

---@return nil|_nui_popup_border_style_builtin|_nui_popup_border_style_char_tuple[]
function Border:get()
  local internal = self._

  if internal.type ~= "simple" then
    return nil
  end

  if type(internal.char) == "string" then
    return internal.char
  end

  return to_tuple_list(internal.char)
end

---@alias NuiPopupBorder.constructor fun(popup: NuiPopup, options: nui_popup_border_options): NuiPopupBorder
---@type NuiPopupBorder|NuiPopupBorder.constructor
local NuiPopupBorder = Border

return NuiPopupBorder
