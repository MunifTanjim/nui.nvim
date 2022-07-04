local Border = require("nui.popup.border")
local buf_storage = require("nui.utils.buf_storage")
local autocmd = require("nui.utils.autocmd")
local keymap = require("nui.utils.keymap")

local utils = require("nui.utils")
local _ = utils._
local defaults = utils.defaults
local is_type = utils.is_type

local layout_utils = require("nui.layout.utils")
local calculate_window_position = layout_utils.calculate_window_position
local calculate_window_size = layout_utils.calculate_window_size
local get_container_info = layout_utils.get_container_info
local parse_relative = layout_utils.parse_relative
local u = {
  size = layout_utils.size,
  position = layout_utils.position,
}

-- @deprecated
---@param opacity number
local function calculate_winblend(opacity)
  assert(0 <= opacity, "opacity must be equal or greater than 0")
  assert(opacity <= 1, "opacity must be equal or lesser than 0")
  return 100 - (opacity * 100)
end

local function merge_default_options(options)
  options.relative = defaults(options.relative, "win")

  options.enter = defaults(options.enter, false)
  options.zindex = defaults(options.zindex, 50)

  options.buf_options = defaults(options.buf_options, {})
  options.win_options = defaults(options.win_options, {})

  options.border = defaults(options.border, "none")

  return options
end

local function normalize_options(options)
  options = _.normalize_layout_options(options)

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

  options = merge_default_options(options)
  options = normalize_options(options)

  self._ = {
    buf_options = options.buf_options,
    layout = {},
    layout_ready = false,
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
  else
    self:_buf_create()
  end

  if not self._.win_options.winblend and is_type("number", options.opacity) then
    -- @deprecated
    self._.win_options.winblend = calculate_winblend(options.opacity)
  end

  -- @deprecated
  if not self._.win_options.winhighlight and not is_type("nil", options.highlight) then
    self._.win_options.winhighlight = options.highlight
  end

  self.border = Border(self, options.border)
  self.win_config.border = self.border:get()

  if options.position and options.size then
    self:update_layout(options)
  end

  return self
end

--luacheck: push no max line length

---@alias nui_popup_internal_position { relative: "'cursor'"|"'editor'"|"'win'", win: number, bufpos?: number[], row: number, col: number }
---@alias nui_popup_internal_size { height: number, width: number }
---@alias nui_popup_internal { layout: nui_layout_config, layout_ready: boolean, loading: boolean, mounted: boolean, position: nui_popup_internal_position, size: nui_popup_internal_size, win_enter: boolean, unmanaged_bufnr?: boolean, buf_options: table<string,any>, win_options: table<string,any> }
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

function Popup:_buf_create()
  if not self.bufnr then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    assert(self.bufnr, "failed to create buffer")
  end
end

function Popup:mount()
  if not self._.layout_ready then
    return error("layout is not ready")
  end

  if self._.loading or self._.mounted then
    return
  end

  self._.loading = true

  self.border:mount()

  self:_buf_create()

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

function Popup:_buf_destory()
  buf_storage.cleanup(self.bufnr)

  if self._.unmanaged_bufnr or not self.bufnr then
    return
  end

  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end

  self.bufnr = nil
end

function Popup:unmount()
  if self._.loading or not self._.mounted then
    return
  end

  self._.loading = true

  self.border:unmount()

  self:_buf_destory()

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
  if not self.bufnr then
    error("popup buffer not found.")
  end

  return keymap.set(self.bufnr, mode, key, handler, opts, force)
end

---@param mode string check `:h :map-modes`
---@param key string|string[] key for the mapping
---@return nil
function Popup:unmap(mode, key, force)
  if not self.bufnr then
    error("popup buffer not found.")
  end

  return keymap._del(self.bufnr, mode, key, force)
end

---@param event string | string[]
---@param handler string | function
---@param options nil | table<"'once'" | "'nested'", boolean>
function Popup:on(event, handler, options)
  if not self.bufnr then
    error("popup buffer not found.")
  end

  autocmd.buf.define(self.bufnr, event, handler, options)
end

---@param event nil | string | string[]
function Popup:off(event)
  if not self.bufnr then
    error("popup buffer not found.")
  end

  autocmd.buf.remove(self.bufnr, nil, event)
end

---@param config nui_layout_config
function Popup:_update_layout_config(config)
  local options = _.normalize_layout_options({
    relative = config.relative,
    size = config.size,
    position = config.position,
  })

  local win_config = self.win_config

  if options.relative then
    self._.layout.relative = options.relative

    local fallback_winid = self._.position and self._.position.win or vim.api.nvim_get_current_win()
    self._.position = vim.tbl_extend(
      "force",
      self._.position or {},
      parse_relative(self._.layout.relative, fallback_winid)
    )

    win_config.relative = self._.position.relative
    win_config.win = self._.position.relative == "win" and self._.position.win or nil
    win_config.bufpos = self._.position.bufpos
  end

  if not win_config.relative then
    return error("missing layout config: relative")
  end

  local prev_container_size = self._.container and self._.container.size
  self._.container = get_container_info(self._.position)
  local container_size_changed = not u.size.are_same(self._.container.size, prev_container_size)

  local need_size_refresh = container_size_changed
    and self._.layout.size
    and u.size.contains_percentage_string(self._.layout.size)

  if options.size or need_size_refresh then
    self._.layout.size = options.size or self._.layout.size

    self._.size = calculate_window_size(self._.layout.size, self._.container.size)

    win_config.width = self._.size.width
    win_config.height = self._.size.height
  end

  if not win_config.width or not win_config.height then
    return error("missing layout config: size")
  end

  local need_position_refresh = container_size_changed
    and self._.layout.position
    and u.position.contains_percentage_string(self._.layout.position)

  if options.position or need_position_refresh then
    self._.layout.position = options.position or self._.layout.position

    self._.position = vim.tbl_extend(
      "force",
      self._.position,
      calculate_window_position(self._.layout.position, self._.size, self._.container)
    )

    win_config.row = self._.position.row
    win_config.col = self._.position.col
  end

  if not win_config.row or not win_config.col then
    return error("missing layout config: position")
  end
end

-- @deprecated
-- Use `popup:update_layout`.
---@deprecated
function Popup:set_layout(config)
  return self:update_layout(config)
end

---@param config? nui_layout_config
function Popup:update_layout(config)
  config = config or {}

  self:_update_layout_config(config)

  self.border:_relayout()

  self._.layout_ready = true

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self.win_config)
  end
end

-- luacov: disable
-- @deprecated
-- Use `popup:update_layout`.
---@deprecated
function Popup:set_size(size)
  self:update_layout({ size = size })
end
-- luacov: enable

-- luacov: disable
-- @deprecated
-- Use `popup:update_layout`.
---@deprecated
function Popup:set_position(position, relative)
  self:update_layout({ position = position, relative = relative })
end
-- luacov: enable

---@alias NuiPopup.constructor fun(options: table): NuiPopup
---@type NuiPopup|NuiPopup.constructor
local NuiPopup = Popup

return NuiPopup
