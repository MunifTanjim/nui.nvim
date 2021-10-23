local Border = require("nui.popup.border")
local buf_storage = require("nui.utils.buf_storage")
local autocmd = require("nui.utils.autocmd")
local keymap = require("nui.utils.keymap")
local utils = require("nui.utils")
local is_type = utils.is_type

local function get_container_info(position_meta)
  local relative = position_meta.relative

  if relative == "editor" then
    return {
      relative = relative,
      size = utils.get_editor_size(),
      type = "editor",
    }
  end

  if relative == "cursor" or relative == "win" then
    return {
      relative = position_meta.bufpos and "buf" or relative,
      size = utils.get_window_size(position_meta.win),
      type = "window",
    }
  end
end

local function calculate_window_size(size, container_size)
  if not is_type("table", size) then
    size = {
      width = size,
      height = size,
    }
  end

  local width = utils._.normalize_dimension(size.width, container_size.width)
  assert(width, "invalid size.width")

  local height = utils._.normalize_dimension(size.height, container_size.height)
  assert(height, "invalid size.height")

  return {
    width = width,
    height = height,
  }
end

local function calculate_window_position(position, size, container)
  local row
  local col

  local is_percentage_allowed = not vim.tbl_contains({ "buf", "cursor" }, container.relative)
  local percentage_error = string.format("position %% can not be used relative to %s", container.relative)

  if is_type("table", position) then
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
  else
    local n = utils.parse_number_input(position)
    assert(n.value ~= nil, "invalid position")
    if n.is_percentage then
      assert(is_percentage_allowed, percentage_error)
      row = math.floor((container.size.height - size.height) * n.value)
      col = math.floor((container.size.width - size.width) * n.value)
    else
      row = n.value
      col = n.value
    end
  end

  return {
    row = row,
    col = col,
  }
end

-- @deprecated
---@param opacity number
local function calculate_winblend(opacity)
  assert(0 <= opacity, "opacity must be equal or greater than 0")
  assert(opacity <= 1, "opacity must be equal or lesser than 0")
  return 100 - (opacity * 100)
end

local function parse_relative(relative, fallback_winid)
  local winid = utils.defaults(relative.winid, fallback_winid)

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

local function normalize_options(options)
  options.enter = utils.defaults(options.enter, false)
  options.zindex = utils.defaults(options.zindex, 50)

  options.relative = utils.defaults(options.relative, "win")
  if is_type("string", options.relative) then
    options.relative = {
      type = options.relative,
    }
  end

  options.buf_options = utils.defaults(options.buf_options, {})
  options.win_options = utils.defaults(options.win_options, {})

  options.border = utils.defaults(options.border, "none")
  if is_type("string", options.border) then
    options.border = {
      style = options.border,
    }
  end

  return options
end

local function init(class, options)
  local self = setmetatable({}, class)

  options = normalize_options(options)

  self.popup_state = {
    loading = false,
    mounted = false,
  }

  self.popup_props = {
    win_enter = options.enter,
  }

  self.win_config = {
    focusable = options.focusable,
    style = "minimal",
    zindex = options.zindex,
  }

  self.buf_options = options.buf_options
  self.win_options = options.win_options

  if not self.win_options.winblend and is_type("number", options.opacity) then
    -- @deprecated
    self.win_options.winblend = calculate_winblend(options.opacity)
  end

  if not self.win_options.winhighlight and not is_type("nil", options.highlight) then
    -- @deprecated
    self.win_options.winhighlight = options.highlight
  end

  local props = self.popup_props
  local state = self.popup_state
  local win_config = self.win_config

  state.position_meta = parse_relative(options.relative, vim.api.nvim_get_current_win())
  win_config.relative = state.position_meta.relative
  win_config.win = state.position_meta.relative == "win" and state.position_meta.win or nil
  win_config.bufpos = state.position_meta.bufpos

  local container_info = get_container_info(state.position_meta)

  props.size = calculate_window_size(options.size, container_info.size)
  win_config.width = props.size.width
  win_config.height = props.size.height

  state.position = calculate_window_position(options.position, props.size, container_info)
  win_config.row = state.position.row
  win_config.col = state.position.col

  self.border = Border(self, options.border)

  win_config.border = self.border:get()

  if win_config.width < 1 then
    error("width can not be negative. is padding more than width?")
  end

  if win_config.height < 1 then
    error("height can not be negative. is padding more than height?")
  end

  return self
end

local Popup = {
  name = "Popup",
  super = nil,
}

function Popup:init(options)
  return init(self, options)
end

function Popup:mount()
  if self.popup_state.loading or self.popup_state.mounted then
    return
  end

  self.popup_state.loading = true

  self.border:mount()

  self.bufnr = vim.api.nvim_create_buf(false, true)
  assert(self.bufnr, "failed to create buffer")

  for name, value in pairs(self.buf_options) do
    vim.api.nvim_buf_set_option(self.bufnr, name, value)
  end

  self.winid = vim.api.nvim_open_win(self.bufnr, self.popup_props.win_enter, self.win_config)
  assert(self.winid, "failed to create popup window")

  for name, value in pairs(self.win_options) do
    vim.api.nvim_win_set_option(self.winid, name, value)
  end

  self.popup_state.loading = false
  self.popup_state.mounted = true
end

function Popup:unmount()
  if self.popup_state.loading or not self.popup_state.mounted then
    return
  end

  self.popup_state.loading = true

  self.border:unmount()

  buf_storage.cleanup(self.bufnr)

  if self.bufnr then
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
    self.bufnr = nil
  end

  if self.winid then
    if vim.api.nvim_win_is_valid(self.winid) then
      vim.api.nvim_win_close(self.winid, true)
    end
    self.winid = nil
  end

  self.popup_state.loading = false
  self.popup_state.mounted = false
end

-- set keymap for this popup window. if keymap was already set and
-- `force` is not `true` returns `false`, otherwise returns `true`
---@param mode "'i'" | "'n'"
---@param key string
---@param handler any
---@param opts table<"'expr'" | "'noremap'" | "'nowait'" | "'script'" | "'silent'" | "'unique'", boolean>
---@param force boolean
---@return boolean ok
function Popup:map(mode, key, handler, opts, force)
  if not self.popup_state.mounted then
    error("popup window is not mounted yet. call popup:mount()")
  end

  return keymap.set(self.bufnr, mode, key, handler, opts, force)
end

---@param event string | string[]
---@param handler string | function
---@param options nil | table<"'once'" | "'nested'", boolean>
function Popup:on(event, handler, options)
  autocmd.buf.define(self.bufnr, event, handler, options)
end

---@param event nil | string | string[]
function Popup:off(event)
  autocmd.buf.remove(self.bufnr, nil, event)
end

function Popup:set_size(size)
  local props = self.popup_props

  local container_info = get_container_info(self.popup_state.position_meta)

  props.size = calculate_window_size(size, container_info.size)
  self.win_config.width = props.size.width
  self.win_config.height = props.size.height

  if self.border.win_config then
    self.border:resize()
  end

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self.win_config)
  end
end

function Popup:set_position(position, relative)
  local props = self.popup_props
  local state = self.popup_state
  local win_config = self.win_config

  if relative then
    state.position_meta = parse_relative(relative, state.position_meta.win)
    win_config.relative = state.position_meta.relative
    win_config.win = state.position_meta.relative == "win" and state.position_meta.win or nil
    win_config.bufpos = state.position_meta.bufpos
  end

  local container_info = get_container_info(state.position_meta)

  state.position = calculate_window_position(position, props.size, container_info)
  win_config.row = state.position.row
  win_config.col = state.position.col

  if self.border.win_config then
    self.border:reposition()
  end

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self.win_config)
  end
end

local PopupClass = setmetatable({
  __index = Popup,
}, {
  __call = init,
  __index = Popup,
})

return PopupClass
