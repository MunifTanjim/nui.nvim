local Line = require("nui.line")
local Popup = require("nui.popup")
local Text = require("nui.text")
local Tree = require("nui.tree")
local _ = require("nui.utils")._
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type

local function prepare_items(items)
  local max_width = 0

  for index, item in ipairs(items) do
    item._index = index

    local width = 0
    if is_type("string", item.text) then
      width = vim.api.nvim_strwidth(item.text)
    elseif is_type("table", item.text) and item.text.width then
      width = item.text:width()
    end

    if max_width < width then
      max_width = width
    end
  end

  return items, max_width
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

local function default_should_skip_item(node)
  return node._type == "separator"
end

local function make_default_prepare_node(menu)
  local props = menu.menu_props
  local popup_props = menu.popup_props
  local border_props = menu.border.border_props

  local default_char = is_type("table", border_props.char) and border_props.char.top or " "
  local default_text_align = is_type("table", border_props.text) and border_props.text.top_align or "left"

  local separator_char = defaults(props.separator.char, default_char)
  local separator_text_align = defaults(props.separator.text_align, default_text_align)

  local max_width = popup_props.size.width
  local separator_max_width = max_width - vim.api.nvim_strwidth(separator_char) * 2

  return function(node)
    local text = is_type("string", node.text) and Text(node.text) or node.text

    local truncate_width = node._type == "separator" and separator_max_width or max_width
    if text:width() > truncate_width then
      text:set(_.truncate_text(text:content(), truncate_width))
    end

    if node._type == "item" then
      return Line({ text })
    elseif node._type == "separator" then
      local gap_width = separator_max_width - text:width()
      local line = Line()
      line:append(separator_char)
      _.align_line(defaults(separator_text_align, "center"), line, text, separator_char, nil, gap_width)
      line:append(separator_char)
      return line
    end
  end
end

---@param direction "'next'" | "'prev'"
---@param current_linenr nil | number
local function focus_item(menu, direction, current_linenr)
  if not menu.popup_state.mounted then
    return
  end

  local curr_linenr = current_linenr or vim.api.nvim_win_get_cursor(menu.winid)[1]

  local next_linenr = nil

  if direction == "next" then
    if curr_linenr == #menu._tree.nodes.root_ids then
      next_linenr = 1
    else
      next_linenr = curr_linenr + 1
    end
  elseif direction == "prev" then
    if curr_linenr == 1 then
      next_linenr = #menu._tree.nodes.root_ids
    else
      next_linenr = curr_linenr - 1
    end
  end

  local next_node = menu._tree:get_node(next_linenr)

  if menu._should_skip_item(next_node) then
    return focus_item(menu, direction, next_linenr)
  end

  if next_linenr then
    vim.api.nvim_win_set_cursor(menu.winid, { next_linenr, 0 })
    menu.menu_props._on_change(next_node, menu)
  end
end

local function init(class, popup_options, options)
  local props = {
    separator = defaults(options.separator, {}),
    keymap = parse_keymap(options.keymap),
  }

  local items, max_width = prepare_items(options.lines)

  local width = math.max(math.min(max_width, defaults(options.max_width, 256)), defaults(options.min_width, 4))
  local height = math.max(math.min(#items, defaults(options.max_height, 256)), defaults(options.min_height, 1))

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

  self._items = items

  self.menu_props = props

  self._should_skip_item = defaults(options.should_skip_item, default_should_skip_item)
  self._prepare_item = defaults(options.prepare_item, make_default_prepare_node(self))

  props._on_change = function(node)
    if options.on_change then
      options.on_change(node, self)
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

---@param text? string|table # text content or NuiText object
---@returns table NuiTreeNode
function Menu.separator(text)
  return Tree.Node({
    _type = "separator",
    text = defaults(text, ""),
  })
end

---@param text string|table # text content or NuiText object
---@param data? table
---@returns table NuiTreeNode
function Menu.item(text, data)
  if not data then
    ---@diagnostic disable-next-line: undefined-field
    if is_type("table", text) and text.text then
      data = text
    else
      data = { text = text }
    end
  else
    data.text = text
  end

  data._type = "item"

  return Tree.Node(data)
end

function Menu:init(popup_options, options)
  return init(self, popup_options, options)
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
    ns_id = self.ns_id,
    nodes = self._items,
    get_node_id = function(node)
      return node._index
    end,
    prepare_node = self._prepare_item,
  })

  self._tree:render()

  -- focus first item
  for _, node_id in ipairs(self._tree.nodes.root_ids) do
    local node = self._tree:get_node(node_id)
    if not self._should_skip_item(node) then
      vim.api.nvim_win_set_cursor(self.winid, { node_id, 0 })
      props._on_change(node, self)
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
