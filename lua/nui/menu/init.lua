local _ = require("nui.utils")._
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type
local Popup = require("nui.popup")
local Tree = require("nui.tree")

local function prepare_lines(lines)
  local data = {
    lines = {},
    _max_line_width = 0,
  }

  for index, line in ipairs(lines) do
    line._index = index

    if line.type == "item" then
      local line_length = vim.api.nvim_strwidth(line.text)
      if data._max_line_width < line_length then
        data._max_line_width = line_length
      end

      data.lines[index] = line
    elseif line.type == "separator" then
      data.lines[index] = line
    end
  end

  return data
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
---@param current_id nil | number
local function focus_item(menu, direction, current_id)
  if not menu.popup_state.mounted then
    return
  end

  local curr_node = menu._tree:get_node(current_id)
  local curr_id = curr_node:get_id()

  local next_id = nil

  if direction == "next" then
    if curr_id == #menu._tree.nodes.root_ids then
      next_id = 1
    else
      next_id = curr_id + 1
    end
  elseif direction == "prev" then
    if curr_id == 1 then
      next_id = #menu._tree.nodes.root_ids
    else
      next_id = curr_id - 1
    end
  end

  local next_node = menu._tree:get_node(next_id)

  if next_node.type == "separator" then
    return focus_item(menu, direction, next_id)
  end

  if next_id then
    vim.api.nvim_win_set_cursor(menu.winid, { next_id, 0 })
    menu.menu_props._on_change(next_node)
  end
end

local function init(class, popup_options, options)
  local props = vim.tbl_extend("force", {
    separator = defaults(options.separator, {}),
    keymap = parse_keymap(options.keymap),
  }, prepare_lines(options.lines))

  local width = math.max(
    math.min(props._max_line_width, defaults(options.max_width, 999)),
    defaults(options.min_width, 16)
  )
  local height = math.max(math.min(#props.lines, defaults(options.max_height, 999)), defaults(options.min_height, 1))

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

  props._on_change = function(node)
    if options.on_change then
      options.on_change(node)
    end
  end

  props.on_submit = function()
    local item = self._tree:get_node()

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
  return Tree.Node({
    type = "separator",
    text = defaults(text, ""),
  })
end

---@param item string | table
---@param props table | nil
function Menu.item(item, props)
  local object = is_type("string", item) and defaults(props, {}) or item

  if is_type("string", item) then
    object.text = item
  end

  object.type = "item"

  return Tree.Node(object)
end

function Menu:init(popup_options, options)
  return init(self, popup_options, options)
end

local function make_prepare_node(menu)
  local props = menu.menu_props
  local popup_props = menu.popup_props
  local border_props = menu.border.border_props

  local default_char = is_type("table", border_props.char) and border_props.char.top or ""
  local default_text_align = is_type("table", border_props.text) and border_props.text.top_align or "left"

  local separator_char = defaults(props.separator.char, default_char)
  local separator_text_align = defaults(props.separator.text_align, default_text_align)

  local max_length = popup_props.size.width
  local separator_max_length = max_length - vim.api.nvim_strwidth(separator_char) * 2

  return function(node)
    if node.type == "item" then
      local text = _.truncate_text(node.text, max_length)
      return text
    elseif node.type == "separator" then
      local text = _.align_text(
        _.truncate_text(node.text, separator_max_length),
        separator_text_align,
        separator_max_length,
        separator_char
      )
      return separator_char .. text .. separator_char
    end
  end
end

function Menu:mount()
  self.super.mount(self)

  local props = self.menu_props

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

  self._tree = Tree({
    winid = self.winid,
    nodes = self.menu_props.lines,
    get_node_id = function(node)
      return node._index
    end,
    prepare_node = make_prepare_node(self),
  })

  self._tree:render()

  -- focus first item
  for _, node_id in ipairs(self._tree.nodes.root_ids) do
    local node = self._tree:get_node(node_id)
    if node.type == "item" then
      vim.api.nvim_win_set_cursor(self.winid, { node_id, 0 })
      props._on_change(node)
      break
    end
  end
end

local MenuClass = setmetatable({
  __index = Menu,
}, {
  __call = init,
  __index = Menu,
})

return MenuClass
