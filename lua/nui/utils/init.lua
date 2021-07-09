local utils = {}

function utils.get_editor_size()
  return {
    width = vim.o.columns,
    height = vim.o.lines
  }
end

function utils.get_window_size(window_id)
  window_id = window_id or 0
  return {
    width = vim.api.nvim_win_get_width(window_id),
    height = vim.api.nvim_win_get_height(window_id),
  }
end

function utils.defaults(v, default_value)
  return type(v) == "nil" and default_value or v
end

---@param type_name "'number'" | "'string'" | "'boolean'" | "'table'" | "'function'" | "'thread'" | "'userdata'"
function utils.is_type(type_name, v)
  return type(v) == type_name
end

---@param v string | number
function utils.parse_number_input(v)
  local parsed = {}

  parsed.is_percentage = type(v) == "string" and string.sub(v, -1) == "%" 

  if parsed.is_percentage then
    parsed.value = tonumber(string.sub(v, 1, #v - 1)) / 100
  else
    parsed.value = tonumber(v)
  end

  return parsed
end

return utils
