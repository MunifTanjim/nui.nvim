local hologram = require("hologram")
local Image = require("hologram.image")
local dimensions = require("hologram.state").dimensions
local cairo = require("hologram.cairo.cairo")

local Line = require("nui.line")
local Text = require("nui.text")
local _ = require("nui.utils")._
local defaults = require("nui.utils").defaults
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

local function parse_winhl(winhl)
  winhl = defaults(winhl, '')
  local parts = vim.split(winhl, ',')
  local entries = vim.tbl_map(function(part) vim.split(part, ':') end, parts)
  local result = {}
  for _, entry in ipairs(entries) do
    result[entry[1]] = entry[2]
  end
  return result
end

local function color_to_rgb(value)
  local red   = bit.rshift(bit.band(value, 0x0ff0000), 16) / 255
  local green = bit.rshift(bit.band(value, 0x000ff00),  8) / 255
  local blue  = bit.rshift(bit.band(value, 0x00000ff),  0) / 255
  return { red, green, blue }
end

local function to_border_map(ImageBorder)
  if not is_type("list", ImageBorder) then
    error("invalid data")
  end

  -- fillup all 8 characters
  local count = vim.tbl_count(ImageBorder)
  if count < 8 then
    for i = count + 1, 8 do
      local fallback_index = i % count
      local char = ImageBorder[fallback_index == 0 and count or fallback_index]
      if is_type("table", char) then
        char = char.content and Text(char) or vim.deepcopy(char)
      end
      ImageBorder[i] = char
    end
  end

  local named_border = {}

  for index, name in ipairs(index_name) do
    named_border[name] = ImageBorder[index]
  end

  return named_border
end

local function to_border_list(named_border)
  if not is_type("map", named_border) then
    error("invalid data")
  end

  local ImageBorder = {}

  for index, name in ipairs(index_name) do
    if is_type(named_border[name], "nil") then
      error(string.format("missing named ImageBorder: %s", name))
    end

    ImageBorder[index] = named_border[name]
  end

  return ImageBorder
end

---@param internal nui_popup_border_internal
local function normalize_highlight(internal)
  -- @deprecated
  if internal.highlight and string.match(internal.highlight, ":") then
    internal.winhighlight = internal.highlight
    internal.highlight = nil
  end

  if not internal.highlight and internal.winhighlight then
    internal.highlight = string.match(internal.winhighlight, "FloatBorder:([^,]+)")
  end

  return internal.highlight or "FloatBorder"
end

---@return nui_popup_border_internal_padding|nil
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
---@param text? nil | string | table # string or NuiText
---@param align? nil | "'left'" | "'center'" | "'right'"
---@return table NuiLine
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

  local content_text = Text(defaults(text, ""))
  if mid_char:width() == 0 then
    content_text:set(string.rep(" ", max_width))
  else
    content_text:set(_.truncate_text(content_text:content(), max_width))
  end

  local left_gap_width, right_gap_width = _.calculate_gap_width(
    defaults(align, "center"),
    max_width,
    content_text:width()
  )

  local line = Line()

  line:append(left_char)

  if left_gap_width > 0 then
    line:append(Text(mid_char):set(string.rep(mid_char:content(), left_gap_width)))
  end

  line:append(content_text)

  if right_gap_width > 0 then
    line:append(Text(mid_char):set(string.rep(mid_char:content(), right_gap_width)))
  end

  line:append(right_char)

  return line
end

---@return nil | table[] # NuiLine[]
local function calculate_buf_lines(internal)
  local char, size, text = internal.char, internal.size, defaults(internal.text, {})

  if is_type("string", char) then
    return nil
  end

  local left_char, right_char = char.left, char.right

  local gap_length = size.width - left_char:width() - right_char:width()

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
  double = "double",
  none = "none",
  rounded = "rounded",
  shadow = "shadow",
  single = "single",
  solid = "solid",
}

---@param ImageBorder NuiPopupImageBorder
---@return nui_popup_border_internal_size
local function calculate_size(ImageBorder)
  ---@type nui_popup_border_internal_size
  local size = vim.deepcopy(ImageBorder.popup._.size)

  local char = ImageBorder._.char

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

  local padding = ImageBorder._.padding

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

---@param ImageBorder NuiPopupImageBorder
---@return nui_popup_border_internal_position
local function calculate_position(ImageBorder)
  local position = vim.deepcopy(ImageBorder.popup._.position)
  return position
end

local function adjust_popup_win_config(ImageBorder)
  local internal = ImageBorder._

  if internal.type ~= "complex" then
    return
  end

  local popup_position = {
    row = 0,
    col = 0,
  }

  local char = internal.char

  if is_type("map", char) then
    if char.top ~= "" then
      popup_position.row = popup_position.row + 1
    end

    if char.left ~= "" then
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

  local popup = ImageBorder.popup

  if not has_nvim_0_5_1 then
    popup.win_config.row = internal.position.row + popup_position.row
    popup.win_config.col = internal.position.col + popup_position.col
    return
  end

  popup.win_config.relative = "win"
  popup.win_config.win = ImageBorder.winid
  popup.win_config.bufpos = nil
  popup.win_config.row = popup_position.row
  popup.win_config.col = popup_position.col
end

---@param class NuiPopupImageBorder
---@param popup NuiPopup
local function init(class, popup, options)
  ---@type NuiPopupImageBorder
  local self = setmetatable({}, { __index = class })

  self.popup = popup

  self._ = {
    type = options.type or "simple",
    style = defaults(options.style, "none"),
    -- @deprecated
    highlight = options.highlight,
    padding = parse_padding(options.padding),
    text = options.text,
    winhighlight = self.popup._.win_options.winhighlight,
    image = nil,
  }

  local internal = self._

  internal.highlight = normalize_highlight(internal)

  return self
end

---@class NuiPopupImageBorder
---@field bufnr number
---@field private _ nui_popup_border_internal
---@field private popup NuiPopup
---@field winid number
local ImageBorder = setmetatable({
  super = nil,
}, {
  __call = init,
  __name = "NuiPopupImageBorder",
})

function ImageBorder:init(popup, options)
  return init(self, popup, options)
end

function ImageBorder:_draw()
  local popup = self.popup
  local internal = self._

  if internal.image then
    self:_clear()
  end

  local highlights = parse_winhl(internal.winhighlight)
  local normal_hl = defaults(highlights['NormalFloat'], 'NormalFloat')
  local border_hl = defaults(highlights['FloatBorder'], 'FloatBorder')

  local background_color =
    color_to_rgb(
      vim.api.nvim_get_hl_by_name(normal_hl, true).background)
  local border_color =
    color_to_rgb(
      vim.api.nvim_get_hl_by_name(border_hl, true).foreground)

  local cell_pixels = dimensions.cell_pixels
  local cw = cell_pixels.width
  local ch = cell_pixels.height

  local width  = cw * (popup.win_config.width  + 4)
  local height = ch * (popup.win_config.height + 2)

  local surface = cairo.image_surface('argb32', width, height)
  local cr = surface:context()

  -- Testing background
  -- cr:rgba(1.0, 0.0, 0.0, 0.2)
  -- cr:rectangle(0, 0, width, height)
  -- cr:fill()

  local window_x = cw * 2
  local window_y = ch * 1

  local window_width  = width  - 4 * cw
  local window_height = height - 2 * ch

  -- Border
  local line_width = 2
  cr:line_width(line_width)
  cr:rgba(border_color[1], border_color[2], border_color[3], 1.0)
  cr:rectangle(
    window_x - line_width,
    window_y - line_width,
    window_width  + 2 * line_width,
    window_height + 2 * line_width
  )
  cr:stroke()

  -- Shadow
  cr:rgba(0.0, 0.0, 0.0, 0.2)
  cr:rectangle(
    window_x,
    window_y + window_height + line_width,
    window_width + line_width,
    ch / 2
  )
  cr:fill()
  cr:rectangle(
    window_x + window_width + line_width,
    window_y,
    ch / 2,
    window_height + ch / 2 + line_width
  )
  cr:fill()

  surface:flush()

  internal.image = Image.new(surface, {
    col = popup.win_config.col - 2,
    row = popup.win_config.row,
  })
  internal.image:transmit()
end

function ImageBorder:_clear()
  local internal = self._

  if not internal.image then
    return
  end

  internal.image:delete({ free = true })
  internal.image = nil
end

function ImageBorder:mount()
  local popup = self.popup

  if not popup._.loading or popup._.mounted then
    return
  end

  vim.defer_fn(function()
    self:_draw()
  end, 100)
end

function ImageBorder:unmount()
  local popup = self.popup

  if not popup._.loading or not popup._.mounted then
    return
  end

  self:_clear()
end

function ImageBorder:resize()
  local internal = self._

  if internal.type ~= "complex" then
    return
  end

  internal.size = calculate_size(self)
  self.win_config.width = internal.size.width
  self.win_config.height = internal.size.height

  internal.lines = calculate_buf_lines(internal)

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self.win_config)
  end

  if self.bufnr then
    if internal.lines then
      _.render_lines(internal.lines, self.bufnr, self.popup.ns_id, 1, #internal.lines)
    end
  end

  vim.api.nvim_command("redraw")
end

function ImageBorder:reposition()
  local internal = self._

  if internal.type ~= "complex" then
    return
  end

  local position = self.popup._.position
  self.win_config.relative = position.relative
  self.win_config.win = position.relative == "win" and position.win or nil
  self.win_config.bufpos = position.bufpos

  internal.position = calculate_position(self)
  self.win_config.row = internal.position.row
  self.win_config.col = internal.position.col

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self.win_config)
  end

  adjust_popup_win_config(self)

  vim.api.nvim_command("redraw")
end

---@param edge "'top'" | "'bottom'"
---@param text? nil | string | table # string or NuiText
---@param align? nil | "'left'" | "'center'" | "'right'"
function ImageBorder:set_text(edge, text, align)
  local internal = self._

  if not internal.lines or not internal.text then
    return
  end

  internal.text[edge] = text
  internal.text[edge .. "_align"] = defaults(align, internal.text[edge .. "_align"])

  local line = calculate_buf_edge_line(internal, edge, internal.text[edge], internal.text[edge .. "_align"])

  local linenr = edge == "top" and 1 or #internal.lines

  internal.lines[linenr] = line
  line:render(self.bufnr, self.popup.ns_id, linenr)
end

function ImageBorder:get()
  -- FIXME: is implementing this required?
  return nil
end

---@alias NuiPopupImageBorder.constructor fun(popup: NuiPopup, options: table): NuiPopupImageBorder
---@type NuiPopupImageBorder|NuiPopupImageBorder.constructor
local NuiPopupImageBorder = ImageBorder

return NuiPopupImageBorder
