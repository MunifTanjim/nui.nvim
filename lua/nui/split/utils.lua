local utils = require("nui.utils")

local u = {
  defaults = utils.defaults,
  get_editor_size = utils.get_editor_size,
  get_window_size = utils.get_window_size,
  is_type = utils.is_type,
  normalize_dimension = utils._.normalize_dimension,
}

local mod = {}

---@param options table
---@return table options
function mod.merge_default_options(options)
  options.relative = u.defaults(options.relative, "win")
  options.position = u.defaults(options.position, vim.go.splitbelow and "bottom" or "top")

  options.enter = u.defaults(options.enter, true)

  options.buf_options = u.defaults(options.buf_options, {})
  options.win_options = vim.tbl_extend("force", {
    winfixwidth = true,
    winfixheight = true,
  }, u.defaults(options.win_options, {}))

  return options
end

---@param options table
---@return table options
function mod.normalize_layout_options(options)
  if utils.is_type("string", options.relative) then
    options.relative = {
      type = options.relative,
    }
  end

  return options
end

---@param options table
---@return table options
function mod.normalize_options(options)
  options = mod.normalize_layout_options(options)

  return options
end

function mod.parse_relative(relative, fallback_winid)
  local winid = u.defaults(relative.winid, fallback_winid)

  return {
    type = relative.type,
    win = winid,
  }
end

---@param relative nui_split_internal_relative
function mod.get_container_info(relative)
  if relative.type == "editor" then
    return {
      size = u.get_editor_size(),
      type = "editor",
    }
  end

  if relative.type == "win" then
    return {
      size = u.get_window_size(relative.win),
      type = "window",
    }
  end
end

---@param position nui_split_internal_position
---@param size number|string
---@param container_size { width: number, height: number }
---@return { width?: number, height?: number }
function mod.calculate_window_size(position, size, container_size)
  if not size then
    return {}
  end

  if position == "left" or position == "right" then
    return {
      width = u.normalize_dimension(size, container_size.width),
    }
  end

  return {
    height = u.normalize_dimension(size, container_size.height),
  }
end

return mod
