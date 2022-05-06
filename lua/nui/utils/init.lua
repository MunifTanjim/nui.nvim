-- internal utils
local _ = {
  feature = {
    lua_keymap = type(vim.keymap) ~= "nil",
    lua_autocmd = type(vim.api.nvim_create_autocmd) ~= "nil",
  },
}

local utils = {
  _ = _,
}

function utils.get_editor_size()
  return {
    width = vim.o.columns,
    height = vim.o.lines,
  }
end

function utils.get_window_size(winid)
  winid = winid or 0
  return {
    width = vim.api.nvim_win_get_width(winid),
    height = vim.api.nvim_win_get_height(winid),
  }
end

function utils.defaults(v, default_value)
  return type(v) == "nil" and default_value or v
end

-- luacheck: push no max comment line length
---@param type_name "'nil'" | "'number'" | "'string'" | "'boolean'" | "'table'" | "'function'" | "'thread'" | "'userdata'" | "'list'" | '"map"'
function utils.is_type(type_name, v)
  if type_name == "list" then
    return vim.tbl_islist(v)
  end

  if type_name == "map" then
    return type(v) == "table" and not vim.tbl_islist(v)
  end

  return type(v) == type_name
end
-- luacheck: pop

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

---@private
---@param bufnr number
---@param linenr number line number (1-indexed)
---@param char_start number start character position (0-indexed)
---@param char_end number end character position (0-indexed)
---@return number[] byte_range
function _.char_to_byte_range(bufnr, linenr, char_start, char_end)
  local line = vim.api.nvim_buf_get_lines(bufnr, linenr - 1, linenr, false)[1]
  local skipped_part = vim.fn.strcharpart(line, 0, char_start)
  local target_part = vim.fn.strcharpart(line, char_start, char_end - char_start)

  local byte_start = vim.fn.strlen(skipped_part)
  local byte_end = math.min(byte_start + vim.fn.strlen(target_part), vim.fn.strlen(line))
  return { byte_start, byte_end }
end

local fallback_namespace_id = vim.api.nvim_create_namespace("nui.nvim")

---@private
---@param ns_id number
---@return number
function _.ensure_namespace_id(ns_id)
  return ns_id == -1 and fallback_namespace_id or ns_id
end

---@private
---@param ns_id? number
---@return number ns_id namespace id
function _.normalize_namespace_id(ns_id)
  if utils.is_type("string", ns_id) then
    return vim.api.nvim_create_namespace(ns_id)
  end
  return ns_id or fallback_namespace_id
end

---@private
---@param bufnr number
---@param buf_options table<string, any>
function _.set_buf_options(bufnr, buf_options)
  for name, value in pairs(buf_options) do
    vim.api.nvim_buf_set_option(bufnr, name, value)
  end
end

---@private
---@param winid number
---@param win_options table<string, any>
function _.set_win_options(winid, win_options)
  for name, value in pairs(win_options) do
    vim.api.nvim_win_set_option(winid, name, value)
  end
end

---@private
---@param dimension number | string
---@param container_dimension number
---@return nil | number
function _.normalize_dimension(dimension, container_dimension)
  local number = utils.parse_number_input(dimension)

  if not number.value then
    return nil
  end

  if number.is_percentage then
    return math.floor(container_dimension * number.value)
  end

  return number.value
end

---@param text string
---@param max_length number
---@return string
function _.truncate_text(text, max_length)
  if vim.api.nvim_strwidth(text) > max_length then
    return string.sub(text, 1, max_length - 1) .. "…"
  end

  return text
end

---@param align "'left'" | "'center'" | "'right'"
---@param total_width number
---@param text_width number
---@return number left_gap_width, number right_gap_width
function _.calculate_gap_width(align, total_width, text_width)
  local gap_width = total_width - text_width
  if align == "left" then
    return 0, gap_width
  elseif align == "center" then
    return math.floor(gap_width / 2), math.ceil(gap_width / 2)
  elseif align == "right" then
    return gap_width, 0
  end

  error("invalid value align=" .. align)
end

---@param lines table[] NuiLine[]
---@param bufnr number
---@param ns_id number
---@param linenr_start number
---@param linenr_end number
function _.render_lines(lines, bufnr, ns_id, linenr_start, linenr_end)
  vim.api.nvim_buf_set_lines(
    bufnr,
    linenr_start - 1,
    linenr_end - 1,
    false,
    vim.tbl_map(function(line)
      return line:content()
    end, lines)
  )

  for linenr, line in ipairs(lines) do
    line:highlight(bufnr, ns_id, linenr)
  end
end

function _.normalize_layout_options(options)
  options.relative = utils.defaults(options.relative, "win")
  if utils.is_type("string", options.relative) then
    options.relative = {
      type = options.relative,
    }
  end

  if not utils.is_type("table", options.position) then
    options.position = {
      row = options.position,
      col = options.position,
    }
  end

  if not utils.is_type("table", options.size) then
    options.size = {
      width = options.size,
      height = options.size,
    }
  end

  return options
end

return utils
