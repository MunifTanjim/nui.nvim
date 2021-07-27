local _utils = require("nui.utils")._
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type
local event = require("nui.utils.autocmd").event
local Popup = require("nui.popup")

local function parse_lines(lines)
  local data = {
    lines = {},
    total_lines = 0,
    max_line_length = 0,
  }

  for index, line in ipairs(lines) do
    data.total_lines = data.total_lines + 1

    line._index = index

    if line.type == "item" then
      table.insert(data.lines, line)

      local line_length = vim.api.nvim_strwidth(line.text)
      if data.max_line_length < line_length then
        data.max_line_length = line_length
      end
    elseif line.type == "separator" then
      table.insert(data.lines, line)
    end
  end

  return data
end

local function calculate_buf_lines(menu)
  local buf_lines = {}

  local border_props = menu.border.border_props

  local default_char = is_type("table", border_props.char) and border_props.char.top or ""
  local default_text_align = is_type("table", border_props.text) and border_props.text.top_align or "left"

  local separator_char = defaults(menu.menu_props.separator.char, default_char)
  local separator_text_align = defaults(menu.menu_props.separator.text_align, default_text_align)

  local max_length = menu.popup_props.size.width
  local separator_max_length = max_length - vim.api.nvim_strwidth(separator_char) * 2

  for _index, line in ipairs(menu.menu_props.lines) do
    if line.type == "item" then
      local text = _utils.truncate_text(line.text, max_length)
      table.insert(buf_lines, text)
    elseif line.type == "separator" then
      local text = _utils.align_text(
        _utils.truncate_text(line.text, separator_max_length),
        separator_text_align,
        separator_max_length,
        separator_char
      )
      table.insert(buf_lines, separator_char .. text .. separator_char)
    end
  end

  return buf_lines
end

local default_keymap = {
  close = { "<Esc>", "<C-c>" },
  focus_next = { "j", "<Down>", "<Tab>" },
  focus_prev = { "k", "<Up>", "<S-Tab>" },
  submit = { "<CR>" },
}

local function parse_keymap(keymap)
  local result = defaults(keymap, {})

  for name, default_keys in pairs(default_keymap) do
    if is_type("nil", result[name]) then
      result[name] = default_keys
    elseif is_type("string", result[name]) then
      result[name] = { result[name] }
    end
  end

  return result
end

---@param direction "'next'" | "'prev'"
---@param current_index nil | number
local function focus_item(menu, direction, current_index)
  if not menu.popup_state.mounted then
    return
  end

  local curr_index = defaults(current_index, menu.menu_state.curr_index)

  local next_index = nil

  if direction == "next" then
    if curr_index == menu.menu_props.total_lines then
      next_index = 1
    else
      next_index = curr_index + 1
    end
  elseif direction == "prev" then
    if curr_index == 1 then
      next_index = menu.menu_props.total_lines
    else
      next_index = curr_index - 1
    end
  end

  if menu.menu_props.lines[next_index].type == "separator" then
    return focus_item(menu, direction, next_index)
  end

  if next_index then
    vim.api.nvim_win_set_cursor(menu.winid, { next_index, 0 })
  end
end

local function init(class, popup_options, options)
  local props = vim.tbl_extend("force", {
    separator = defaults(options.separator, {}),
    keymap = parse_keymap(options.keymap),
  }, parse_lines(
    options.lines
  ))

  local state = {
    curr_index = nil,
  }

  for _, line in ipairs(props.lines) do
    if line.type == "item" then
      state.curr_index = line._index
      break
    end
  end

  local width = math.max(
    math.min(props.max_line_length, defaults(options.max_width, 999)),
    defaults(options.min_width, 16)
  )
  local height = math.max(
    math.min(props.total_lines, defaults(options.max_height, 999)),
    defaults(options.min_height, 1)
  )

  popup_options = vim.tbl_deep_extend("force", {
    enter = true,
    size = {
      width = width,
      height = height,
    },
    win_options = {
      cursorline = true,
      scrolloff = 1,
      sidescrolloff = 0,
    },
  }, popup_options)

  local self = class.super.init(class, popup_options)

  self.menu_props = props
  self.menu_state = state

  props.buf_lines = calculate_buf_lines(self)

  props.on_submit = function()
    local curr_index = self.menu_state.curr_index
    local item = self.menu_props.lines[curr_index]

    self:unmount()

    if options.on_submit then
      options.on_submit(item)
    end
  end

  props.on_close = function()
    self:unmount()

    if options.on_close then
      options.on_close()
    end
  end

  props.on_focus_next = function()
    focus_item(self, "next")
  end

  props.on_focus_prev = function()
    focus_item(self, "prev")
  end

  return self
end

local Menu = setmetatable({
  name = "Menu",
  super = Popup,
}, {
  __index = Popup.__index,
})

---@param text nil | string
function Menu.separator(text)
  return {
    type = "separator",
    text = defaults(text, ""),
  }
end

---@param item string | table
---@param props table | nil
function Menu.item(item, props)
  local object = is_type("string", item) and defaults(props, {}) or item

  if is_type("string", item) then
    object.text = item
  end

  object.type = "item"

  return object
end

function Menu:init(popup_options, options)
  return init(self, popup_options, options)
end

function Menu:mount()
  self.super.mount(self)

  local props = self.menu_props

  self:on(event.CursorMoved, function()
    local index = vim.api.nvim_win_get_cursor(self.winid)[1]
    self.menu_state.curr_index = index
  end, {})

  for _, key in pairs(props.keymap.focus_next) do
    self:map("n", key, props.on_focus_next, { noremap = true, nowait = true })
  end

  for _, key in pairs(props.keymap.focus_prev) do
    self:map("n", key, props.on_focus_prev, { noremap = true, nowait = true })
  end

  for _, key in pairs(props.keymap.close) do
    self:map("n", key, props.on_close, { noremap = true, nowait = true })
  end

  for _, key in pairs(props.keymap.submit) do
    self:map("n", key, props.on_submit, { noremap = true, nowait = true })
  end

  vim.api.nvim_buf_set_lines(self.bufnr, 0, #self.menu_props.buf_lines, false, self.menu_props.buf_lines)
  vim.api.nvim_buf_set_option(self.bufnr, "readonly", true)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
  vim.api.nvim_win_set_cursor(self.winid, { self.menu_state.curr_index, 0 })
end

local MenuClass = setmetatable({
  __index = Menu,
}, {
  __call = init,
  __index = Menu,
})

return MenuClass
