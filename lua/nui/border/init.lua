local TextBorder = require("nui.border.text")
local ImageBorder = require("nui.border.image")

--luacheck: push no max line length

---@alias nui_t_text_align "'left'" | "'center'" | "'right'"
---@alias nui_popup_border_internal_padding { top: number, right: number, bottom: number, left: number }
---@alias nui_popup_border_internal_position { row: number, col: number }
---@alias nui_popup_border_internal_size { width: number, height: number }
---@alias nui_popup_border_internal_text { top?: string, top_align?: nui_t_text_align, bottom?: string, bottom_align?: nui_t_text_align }
---@alias nui_popup_border_internal { type: "'simple'"|"'complex'", style: table, char: any, padding?: nui_popup_border_internal_padding, position: nui_popup_border_internal_position, size: nui_popup_border_internal_size, text: nui_popup_border_internal_text, lines?: table[], winhighlight?: string }

--luacheck: pop


---@param popup NuiPopup
local function init(popup, options)
  local renderer = options.renderer or 'text'

  if renderer == 'text' then
    return TextBorder(popup, options)
  end

  if renderer == 'image' then
    return ImageBorder(popup, options)
  end

  assert(false, 'Unsupported "renderer" value')
end

return init
