local Border = require("nui.popup.border")
local buf_storage = require("nui.utils.buf_storage")
local autocmd = require("nui.utils.autocmd")
local keymap = require("nui.utils.keymap")
local utils = require("nui.utils")

local _ = utils._
local defaults = utils.defaults
local is_type = utils.is_type

---@param position nui_popup_internal_position
local function get_container_info(position)
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

local function calculate_window_size(size, container_size)
  local width = _.normalize_dimension(size.width, container_size.width)
  assert(width, "invalid size.width")

  local height = _.normalize_dimension(size.height, container_size.height)
  assert(height, "invalid size.height")

  return {
    width = width,
    height = height,
  }
end

---@return nui_popup_internal_position
local function calculate_window_position(position, size, container)
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

-- @deprecated
---@param opacity number
local function calculate_winblend(opacity)
  assert(0 <= opacity, "opacity must be equal or greater than 0")
  assert(opacity <= 1, "opacity must be equal or lesser than 0")
  return 100 - (opacity * 100)
end

---@return nui_popup_internal_position
local function parse_relative(relative, fallback_winid)
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

local function normalize_options(options)
  options = _.normalize_layout_options(options)

  options.enter = defaults(options.enter, false)
  options.zindex = defaults(options.zindex, 50)

  options.buf_options = defaults(options.buf_options, {})
  options.win_options = defaults(options.win_options, {})

  options.border = defaults(options.border, "none")
  if is_type("string", options.border) then
    options.border = {
      style = options.border,
    }
  end

  return options
end

---@param class NuiPopup
local function init(class, options)
  ---@type NuiPopup
  local self = setmetatable({}, { __index = class })

  options = normalize_options(options)

  self._ = {
    buf_options = options.buf_options,
    loading = false,
    mounted = false,
    win_enter = options.enter,
    win_options = options.win_options,
  }

  self.win_config = {
    focusable = options.focusable,
    style = "minimal",
    zindex = options.zindex,
  }

  self.ns_id = _.normalize_namespace_id(options.ns_id)

  if options.bufnr then
    self.bufnr = options.bufnr
    self._.unmanaged_bufnr = true
  end

  if not self._.win_options.winblend and is_type("number", options.opacity) then
    -- @deprecated
    self._.win_options.winblend = calculate_winblend(options.opacity)
  end

  -- @deprecated
  if not self._.win_options.winhighlight and not is_type("nil", options.highlight) then
    self._.win_options.winhighlight = options.highlight
  end

  local win_config = self.win_config

  self._.position = parse_relative(options.relative, vim.api.nvim_get_current_win())

  local container_info = get_container_info(self._.position)

  self._.size = calculate_window_size(options.size, container_info.size)
  win_config.width = self._.size.width
  win_config.height = self._.size.height

  self._.position = vim.tbl_extend(
    "force",
    self._.position,
    calculate_window_position(options.position, self._.size, container_info)
  )

  win_config.relative = self._.position.relative
  win_config.win = self._.position.relative == "win" and self._.position.win or nil
  win_config.bufpos = self._.position.bufpos
  win_config.row = self._.position.row
  win_config.col = self._.position.col

  self.border = Border(self, options.border)

  win_config.border = self.border:get()

  return self
end

--luacheck: push no max line length

---@alias nui_popup_internal_position { relative: "'cursor'"|"'editor'"|"'win'", win: number, bufpos?: number[], row: number, col: number }
---@alias nui_popup_internal_size { height: number, width: number }
---@alias nui_popup_internal { loading: boolean, mounted: boolean, position: nui_popup_internal_position, size: nui_popup_internal_size, win_enter: boolean, unmanaged_bufnr?: boolean, buf_options: table<string,any>, win_options: table<string,any> }
---@alias nui_popup_win_config { focusable: boolean, style: "'minimal'", zindex: number, relative: "'cursor'"|"'editor'"|"'win'", win?: number, bufpos?: number[], row: number, col: number, width: number, height: number, border?: table }

--luacheck: pop

---@class NuiPopup
---@field border NuiPopupBorder
---@field bufnr number
---@field ns_id number
---@field private _ nui_popup_internal
---@field win_config nui_popup_win_config
---@field winid number
local Popup = setmetatable({
  super = nil,
}, {
  __call = init,
  __name = "NuiPopup",
})

function Popup:init(options)
  return init(self, options)
end

function Popup:_open_window()
  if self.winid or not self.bufnr then
    return
  end

  self.winid = vim.api.nvim_open_win(self.bufnr, self._.win_enter, self.win_config)
  assert(self.winid, "failed to create popup window")

  _.set_win_options(self.winid, self._.win_options)
end

function Popup:_close_window()
  if not self.winid then
    return
  end

  if vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end

  self.winid = nil
end

function Popup:mount()
  if self._.loading or self._.mounted then
    return
  end

  self._.loading = true

  self.border:mount()

  if not self.bufnr then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    assert(self.bufnr, "failed to create buffer")
  end

  _.set_buf_options(self.bufnr, self._.buf_options)

  self:_open_window()

  self._.loading = false
  self._.mounted = true
end

function Popup:hide()
  if self._.loading or not self._.mounted then
    return
  end

  self._.loading = true

  self.border:_close_window()

  self:_close_window()

  self._.loading = false
end

function Popup:show()
  if self._.loading or not self._.mounted then
    return
  end

  self._.loading = true

  self.border:_open_window()

  self:_open_window()

  self._.loading = false
end

function Popup:unmount()
  if self._.loading or not self._.mounted then
    return
  end

  self._.loading = true

  self.border:unmount()

  buf_storage.cleanup(self.bufnr)

  if self.bufnr and not self._.unmanaged_bufnr then
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
    self.bufnr = nil
  end

  self:_close_window()

  self._.loading = false
  self._.mounted = false
end

-- set keymap for this popup window
---@param mode string check `:h :map-modes`
---@param key string|string[] key for the mapping
---@param handler string | fun(): nil handler for the mapping
---@param opts table<"'expr'"|"'noremap'"|"'nowait'"|"'remap'"|"'script'"|"'silent'"|"'unique'", boolean>
---@return nil
function Popup:map(mode, key, handler, opts, force)
  if not self._.mounted then
    error("popup window is not mounted yet. call popup:mount()")
  end

  return keymap.set(self.bufnr, mode, key, handler, opts, force)
end

---@param mode string check `:h :map-modes`
---@param key string|string[] key for the mapping
---@return nil
function Popup:unmap(mode, key, force)
  if not self._.mounted then
    error("popup window is not mounted yet. call popup:mount()")
  end

  return keymap._del(self.bufnr, mode, key, force)
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
  local container_info = get_container_info(self._.position)

  self._.size = calculate_window_size(size, container_info.size)
  self.win_config.width = self._.size.width
  self.win_config.height = self._.size.height

  self.border:resize()

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self.win_config)
  end
end

function Popup:set_position(position, relative)
  local win_config = self.win_config

  if relative then
    self._.position = vim.tbl_extend("force", self._.position, parse_relative(relative, self._.position.win))
    win_config.relative = self._.position.relative
    win_config.win = self._.position.relative == "win" and self._.position.win or nil
    win_config.bufpos = self._.position.bufpos
  end

  local container_info = get_container_info(self._.position)

  self._.position = vim.tbl_extend(
    "force",
    self._.position,
    calculate_window_position(position, self._.size, container_info)
  )
  win_config.row = self._.position.row
  win_config.col = self._.position.col

  self.border:reposition()

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self.win_config)
  end
end

---@alias NuiPopup.constructor fun(options: table): NuiPopup
---@type NuiPopup|NuiPopup.constructor
local NuiPopup = Popup

return NuiPopup
