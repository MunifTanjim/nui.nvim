local utils = require("nui.utils")

local _ = utils._
local defaults = utils.defaults

--luacheck: push no max line length

---@alias nui_layout_option_relative_type "'cursor'"|"'editor'"|"'win'"|"'buf'"
---@alias nui_layout_option_relative { winid?: number, type: nui_layout_option_relative_type, winid?: number, position?: { row: number, col: number }  }
---@alias nui_layout_internal_position { relative: "'cursor'"|"'editor'"|"'win'", win: number, bufpos?: number[], row: number, col: number }
---@alias nui_layout_container_info { relative: nui_layout_option_relative_type, size: { width: number|string, height: number|string }, type: "'editor'"|"'window'" }

--luacheck: pop

local mod = {}

---@param position { row: number|string, col: number|string }
---@param size { width: number, height: number }
---@param container nui_layout_container_info
---@return { row: number, col: number }
function mod.calculate_window_position(position, size, container)
  local row
  local col

  local is_percentage_allowed = not vim.tbl_contains({ "buf", "cursor" }, container.relative)
  local percentage_error = string.format("position %% can not be used relative to %s", container.relative)

  local r = utils.parse_number_input(position.row)
  assert(r.value ~= nil, "invalid position.row")
  if r.is_percentage then
    assert(is_percentage_allowed, percentage_error)
    row = math.floor((container.size.height - size.height) * r.value)
  else
    row = r.value
  end

  local c = utils.parse_number_input(position.col)
  assert(c.value ~= nil, "invalid position.col")
  if c.is_percentage then
    assert(is_percentage_allowed, percentage_error)
    col = math.floor((container.size.width - size.width) * c.value)
  else
    col = c.value
  end

  return {
    row = row,
    col = col,
  }
end

---@param size { width: number|string, height: number|string }
---@param container_size { width: number|string, height: number|string }
---@return { width: number, height: number }
function mod.calculate_window_size(size, container_size)
  local width = _.normalize_dimension(size.width, container_size.width)
  assert(width, "invalid size.width")

  local height = _.normalize_dimension(size.height, container_size.height)
  assert(height, "invalid size.height")

  return {
    width = width,
    height = height,
  }
end

---@param position nui_layout_internal_position
---@return nui_layout_container_info
function mod.get_container_info(position)
  local relative = position.relative

  if relative == "editor" then
    return {
      relative = relative,
      size = utils.get_editor_size(),
      type = "editor",
    }
  end

  if relative == "cursor" or relative == "win" then
    return {
      relative = position.bufpos and "buf" or relative,
      size = utils.get_window_size(position.win),
      type = "window",
    }
  end
end

---@param relative nui_layout_option_relative
---@param fallback_winid number
---@return nui_layout_internal_position
function mod.parse_relative(relative, fallback_winid)
  local winid = defaults(relative.winid, fallback_winid)

  if relative.type == "buf" then
    return {
      relative = "win",
      win = winid,
      bufpos = {
        relative.position.row,
        relative.position.col,
      },
    }
  end

  return {
    relative = relative.type,
    win = winid,
  }
end

return mod
