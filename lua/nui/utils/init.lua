local ok_nvim_version, nvim_version = pcall(vim.version)
if not ok_nvim_version then
  nvim_version = {}
end

-- internal utils
local _ = {
  feature = {
    lua_keymap = type(vim.keymap) ~= "nil",
    lua_autocmd = type(vim.api.nvim_create_autocmd) ~= "nil",
    v0_10 = nvim_version.minor >= 10,
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
---@return boolean
function utils.is_type(type_name, v)
  -- `vim.tbl_islist` will be removed in the future
  local islist = vim.islist or vim.tbl_islist
  if type_name == "list" then
    return islist(v)
  end

  if type_name == "map" then
    return type(v) == "table" and not islist(v)
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
    parsed.is_percentage = parsed.value and 0 < parsed.value and parsed.value < 1
  end

  return parsed
end

---@param prefix? string
---@return (fun(): string) get_next_id
local function get_id_generator(prefix)
  prefix = prefix or ""
  local id = 0
  return function()
    id = id + 1
    return prefix .. id
  end
end

_.get_next_id = get_id_generator("nui_")

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

---@type integer
local fallback_namespace_id = vim.api.nvim_create_namespace("nui.nvim")

---@private
---@param ns_id integer
---@return integer
function _.ensure_namespace_id(ns_id)
  return ns_id == -1 and fallback_namespace_id or ns_id
end

---@private
---@param ns_id? integer|string
---@return integer ns_id namespace id
function _.normalize_namespace_id(ns_id)
  if utils.is_type("string", ns_id) then
    ---@cast ns_id string
    return vim.api.nvim_create_namespace(ns_id)
  end
  ---@cast ns_id integer
  return ns_id or fallback_namespace_id
end

---@private
---@param bufnr integer
---@param ns_id integer
---@param linenr_start? integer (1-indexed)
---@param linenr_end? integer (1-indexed,inclusive)
function _.clear_namespace(bufnr, ns_id, linenr_start, linenr_end)
  linenr_start = linenr_start or 1
  linenr_end = linenr_end and linenr_end + 1 or 0
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, linenr_start - 1, linenr_end - 1)
end

-- luacov: disable
local nvim_buf_set_option = vim.api.nvim_buf_set_option
---@param bufnr integer
---@param name string
---@param value any
local function set_buf_option(bufnr, name, value)
  nvim_buf_set_option(bufnr, name, value)
end

local nvim_win_set_option = vim.api.nvim_win_set_option
---@param winid integer
---@param name string
---@param value any
local function set_win_option(winid, name, value)
  nvim_win_set_option(winid, name, value)
end
-- luacov: enable

if _.feature.v0_10 then
  function set_buf_option(bufnr, name, value)
    vim.api.nvim_set_option_value(name, value, { buf = bufnr })
  end

  function set_win_option(winid, name, value)
    vim.api.nvim_set_option_value(name, value, { win = winid, scope = "local" })
  end
end

_.set_buf_option = set_buf_option
_.set_win_option = set_win_option

---@private
---@param bufnr number
---@param buf_options table<string, any>
function _.set_buf_options(bufnr, buf_options)
  for name, value in pairs(buf_options) do
    set_buf_option(bufnr, name, value)
  end
end

---@private
---@param winid number
---@param win_options table<string, any>
function _.set_win_options(winid, win_options)
  for name, value in pairs(win_options) do
    set_win_option(winid, name, value)
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

---@param text NuiText
---@param max_width number
function _.truncate_nui_text(text, max_width)
  text:set(_.truncate_text(text:content(), max_width))
end

---@param line NuiLine
---@param max_width number
function _.truncate_nui_line(line, max_width)
  local width = line:width()
  local last_part_idx = #line._texts

  while width > max_width do
    local extra_width = width - max_width
    local last_part = line._texts[last_part_idx]

    if last_part:width() <= extra_width then
      width = width - last_part:width()
      line._texts[last_part_idx] = nil
      last_part_idx = last_part_idx - 1

      -- need to add truncate indicator in previous part
      if last_part:width() == extra_width then
        last_part = line._texts[last_part_idx]
        last_part:set(_.truncate_text(last_part:content() .. " ", last_part:width()))
      end
    else
      last_part:set(_.truncate_text(last_part:content(), last_part:width() - extra_width))
      width = width - extra_width
    end
  end
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

---@param lines (string|NuiLine)[]
---@param bufnr number
---@param ns_id number
---@param linenr_start integer (1-indexed)
---@param linenr_end? integer (1-indexed,inclusive)
---@param byte_start? integer (0-indexed)
---@param byte_end? integer (0-indexed,exclusive)
function _.render_lines(lines, bufnr, ns_id, linenr_start, linenr_end, byte_start, byte_end)
  local row_start = linenr_start - 1
  local row_end = linenr_end or row_start + 1

  local content = vim.tbl_map(function(line)
    if type(line) == "string" then
      return line
    end
    return line:content()
  end, lines)

  if byte_start then
    local col_start = byte_start
    local col_end = byte_end or #vim.api.nvim_buf_get_lines(bufnr, row_start, row_end, false)[1]
    vim.api.nvim_buf_set_text(bufnr, row_start, col_start, row_end - 1, col_end, content)
  else
    vim.api.nvim_buf_set_lines(bufnr, row_start, row_end, false, content)
  end

  for linenr, line in ipairs(lines) do
    if type(line) ~= "string" then
      line:highlight(bufnr, ns_id, linenr + row_start, byte_start)
    end
  end
end

---@param bufnr integer
---@param linenr_start integer (1-indexed)
---@param linenr_end integer (1-indexed,inclusive)
function _.clear_lines(bufnr, linenr_start, linenr_end)
  local count = linenr_end - linenr_start + 1
  if count < 1 then
    return
  end

  local lines = {}
  for i = 1, count do
    lines[i] = ""
  end

  vim.api.nvim_buf_set_lines(bufnr, linenr_start - 1, linenr_end, false, lines)
end

function _.normalize_layout_options(options)
  if utils.is_type("string", options.relative) then
    options.relative = {
      type = options.relative,
    }
  end

  if options.position and not utils.is_type("table", options.position) then
    options.position = {
      row = options.position,
      col = options.position,
    }
  end

  if options.size and not utils.is_type("table", options.size) then
    options.size = {
      width = options.size,
      height = options.size,
    }
  end

  return options
end

---@param winhighlight string
---@return table<string, string> highlight_map
function _.parse_winhighlight(winhighlight)
  local highlight = {}
  local parts = vim.split(winhighlight, ",", { plain = true, trimempty = true })
  for _, part in ipairs(parts) do
    local key, value = part:match("(.+):(.+)")
    highlight[key] = value
  end
  return highlight
end

---@param highlight_map table<string, string>
---@return string winhighlight
function _.serialize_winhighlight(highlight_map)
  local parts = vim.tbl_map(function(key)
    return key .. ":" .. highlight_map[key]
  end, vim.tbl_keys(highlight_map))
  table.sort(parts)
  return table.concat(parts, ",")
end

return utils
