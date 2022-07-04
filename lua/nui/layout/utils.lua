local utils = require("nui.utils")

local _ = utils._
local defaults = utils.defaults

--luacheck: push no max line length

---@alias nui_layout_option_relative_type "'cursor'"|"'editor'"|"'win'"|"'buf'"
---@alias nui_layout_option_relative { type: nui_layout_option_relative_type, winid?: number, position?: { row: number, col: number }  }
---@alias nui_layout_option_position { row: number|string, col: number|string }
---@alias nui_layout_option_size { width: number|string, height: number|string }
---@alias nui_layout_config { relative?: nui_layout_option_relative, size?: nui_layout_option_size, position?: nui_layout_option_position }
---@alias nui_layout_internal_position { relative: "'cursor'"|"'editor'"|"'win'", win: number, bufpos?: number[], row: number, col: number }
---@alias nui_layout_container_info { relative: nui_layout_option_relative_type, size: nui_layout_option_size, type: "'editor'"|"'window'" }

--luacheck: pop

local mod_size = {}
local mod_position = {}

local mod = {
  size = mod_size,
  position = mod_position,
}

---@param position nui_layout_option_position
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
---@param container_size { width: number, height: number }
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

---@param config nui_layout_config
function mod.update_layout_config(component, config)
  local options = _.normalize_layout_options({
    relative = config.relative,
    size = config.size,
    position = config.position,
  })

  local win_config = component._.win_config

  if options.relative then
    component._.layout.relative = options.relative

    local fallback_winid = component._.position and component._.position.win or vim.api.nvim_get_current_win()
    component._.position = vim.tbl_extend(
      "force",
      component._._position or {},
      mod.parse_relative(component._.layout.relative, fallback_winid)
    )

    win_config.relative = component._.position.relative
    win_config.win = component._.position.relative == "win" and component._.position.win or nil
    win_config.bufpos = component._.position.bufpos
  end

  if not win_config.relative then
    return error("missing layout config: relative")
  end

  local prev_container_size = component._.container and component._.container.size
  component._.container = mod.get_container_info(component._.position)
  local container_size_changed = not mod.size.are_same(component._.container.size, prev_container_size)

  local need_size_refresh = container_size_changed
    and component._.layout.size
    and mod.size.contains_percentage_string(component._.layout.size)

  if options.size or need_size_refresh then
    component._.layout.size = options.size or component._.layout.size

    component._.size = mod.calculate_window_size(component._.layout.size, component._.container.size)

    win_config.width = component._.size.width
    win_config.height = component._.size.height
  end

  if not win_config.width or not win_config.height then
    return error("missing layout config: size")
  end

  local need_position_refresh = container_size_changed
    and component._.layout.position
    and mod.position.contains_percentage_string(component._.layout.position)

  if options.position or need_position_refresh then
    component._.layout.position = options.position or component._.layout.position

    component._.position = vim.tbl_extend(
      "force",
      component._.position,
      mod.calculate_window_position(component._.layout.position, component._.size, component._.container)
    )

    win_config.row = component._.position.row
    win_config.col = component._.position.col
  end

  if not win_config.row or not win_config.col then
    return error("missing layout config: position")
  end
end

---@param size_a nui_layout_option_size
---@param size_b? nui_layout_option_size
---@return boolean
function mod_size.are_same(size_a, size_b)
  return size_b and size_a.width == size_b.width and size_a.height == size_b.height
end

---@param size nui_layout_option_size
---@return boolean
function mod_size.contains_percentage_string(size)
  return type(size.width) == "string" or type(size.height) == "string"
end

---@param position nui_layout_option_position
---@return boolean
function mod_position.contains_percentage_string(position)
  return type(position.row) == "string" or type(position.col) == "string"
end

return mod
