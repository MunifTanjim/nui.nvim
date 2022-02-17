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

local styles = {
  double = "double",
  none = "none",
  rounded = "rounded",
  shadow = "shadow",
  single = "single",
  solid = "solid",
}

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

  local padding = 8
  local shadow  = 10

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

  local line_width = 1

  -- Shadow
  for i = 1, shadow do
    local current_shadow = i
    cr:rounded_rectangle(
      window_x - line_width - padding - current_shadow,
      window_y - line_width - padding,
      window_width  + 2 * line_width + 2 * padding + 2 * current_shadow,
      window_height + 2 * line_width + 2 * padding + 1 * current_shadow,
      4
    )
    cr:rgba(0.0, 0.0, 0.0, 0.03)
    cr:fill()
  end

  -- Path for padding & border
  cr:rounded_rectangle(
    window_x - line_width - padding,
    window_y - line_width - padding,
    window_width  + 2 * line_width + 2 * padding,
    window_height + 2 * line_width + 2 * padding,
    4
  )

  -- Padding
  cr:rgba(background_color[1], background_color[2], background_color[3], 1.0)
  cr:fill_preserve()

  -- Border
  cr:line_width(line_width)
  cr:rgba(border_color[1], border_color[2], border_color[3], 1.0)
  cr:stroke()

  -- Clear window region
  cr:operator('source')
  cr:rgba(0, 0, 0, 0)
  cr:rectangle(window_x, window_y, window_width, window_height)
  cr:fill()
  cr:operator('over')

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

  self:_draw()
end

function ImageBorder:unmount()
  local popup = self.popup

  if not popup._.loading or not popup._.mounted then
    return
  end

  self:_clear()
end

function ImageBorder:resize()
  -- FIXME: implement this
  return nil
end

function ImageBorder:reposition()
  -- FIXME: implement this
  return nil
end

---@param edge "'top'" | "'bottom'"
---@param text? nil | string | table # string or NuiText
---@param align? nil | "'left'" | "'center'" | "'right'"
function ImageBorder:set_text(edge, text, align)
  -- FIXME: implement this
  return nil
end

function ImageBorder:get()
  -- FIXME: is implementing this required?
  return nil
end

---@alias NuiPopupImageBorder.constructor fun(popup: NuiPopup, options: table): NuiPopupImageBorder
---@type NuiPopupImageBorder|NuiPopupImageBorder.constructor
local NuiPopupImageBorder = ImageBorder

return NuiPopupImageBorder
