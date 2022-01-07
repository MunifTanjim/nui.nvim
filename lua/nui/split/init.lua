local buf_storage = require("nui.utils.buf_storage")
local autocmd = require("nui.utils.autocmd")
local keymap = require("nui.utils.keymap")
local utils = require("nui.utils")
local defaults = utils.defaults

local split_direction_command_map = {
  editor = {
    top = "topleft",
    right = "vertical botright",
    bottom = "botright",
    left = "vertical topleft",
  },
  win = {
    top = "aboveleft",
    right = "vertical rightbelow",
    bottom = "belowright",
    left = "vertical leftabove",
  },
}

local function get_container_info(split)
  local relative = split.split_props.relative

  if relative == "editor" then
    return {
      size = utils.get_editor_size(),
      type = "editor",
    }
  end

  if relative == "win" then
    return {
      size = utils.get_window_size(),
      type = "window",
    }
  end
end

local function calculate_window_size(split, size, container)
  if not size then
    return {}
  end

  local props = split.split_props

  if props.position == "left" or props.position == "right" then
    return {
      width = utils._.normalize_dimension(size, container.size.width),
    }
  end

  return {
    height = utils._.normalize_dimension(size, container.size.height),
  }
end

---@param class NuiSplit
---@param options table
---@return NuiSplit
local function init(class, options)
  ---@type NuiSplit
  local self = setmetatable({}, { __index = class })

  self._ = {
    buf_options = defaults(options.buf_options, {}),
    loading = false,
    mounted = false,
    win_options = vim.tbl_extend("force", {
      winfixwidth = true,
      winfixheight = true,
    }, defaults(options.win_options, {})),
  }

  self.split_props = {
    relative = defaults(options.relative, "win"),
    position = defaults(options.position, vim.go.splitbelow and "bottom" or "top"),
  }

  local props = self.split_props

  local container_info = get_container_info(self)
  props.size = calculate_window_size(self, options.size, container_info)

  return self
end

--luacheck: push no max line length

---@alias nui_split_internal { loading: boolean, mounted: boolean, buf_options: table<string,any>, win_options: table<string,any> }

--luacheck: pop

---@class NuiSplit
---@field private _ nui_split_internal
---@field bufnr number
---@field winid number
local Split = setmetatable({
  super = nil,
}, {
  __call = init,
  __name = "NuiSplit",
})

function Split:init(options)
  return init(self, options)
end

function Split:_open_window()
  if self.winid or not self.bufnr then
    return
  end

  local props = self.split_props

  vim.api.nvim_command(
    string.format(
      "silent noswapfile %s sbuffer %s",
      split_direction_command_map[props.relative][props.position],
      self.bufnr
    )
  )

  self.winid = vim.fn.win_getid()

  if props.size.width then
    vim.api.nvim_win_set_width(self.winid, props.size.width)
  elseif props.size.height then
    vim.api.nvim_win_set_height(self.winid, props.size.height)
  end

  utils._.set_win_options(self.winid, self._.win_options)
end

function Split:_close_window()
  if not self.winid then
    return
  end

  if vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end

  self.winid = nil
end

function Split:mount()
  if self._.loading or self._.mounted then
    return
  end

  self._.loading = true

  self.bufnr = vim.api.nvim_create_buf(false, true)
  assert(self.bufnr, "failed to create buffer")

  utils._.set_buf_options(self.bufnr, self._.buf_options)

  self:_open_window()

  self._.loading = false
  self._.mounted = true
end

function Split:hide()
  if self._.loading or not self._.mounted then
    return
  end

  self._.loading = true

  self:_close_window()

  self._.loading = false
end

function Split:show()
  if self._.loading or not self._.mounted then
    return
  end

  self._.loading = true

  self:_open_window()

  self._.loading = false
end

function Split:unmount()
  if self._.loading or not self._.mounted then
    return
  end

  self._.loading = true

  buf_storage.cleanup(self.bufnr)

  if self.bufnr then
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
    self.bufnr = nil
  end

  self:_close_window()

  self._.loading = false
  self._.mounted = false
end

-- set keymap for this split. if keymap was already set and
-- `force` is not `true` returns `false`, otherwise returns `true`
---@param mode "'i'" | "'n'"
---@param key string
---@param handler any
---@param opts table<"'expr'" | "'noremap'" | "'nowait'" | "'script'" | "'silent'" | "'unique'", boolean>
---@param force boolean
---@return boolean ok
function Split:map(mode, key, handler, opts, force)
  if not self._.mounted then
    error("split is not mounted yet. call split:mount()")
  end

  return keymap.set(self.bufnr, mode, key, handler, opts, force)
end

---@param event string | string[]
---@param handler string | function
---@param options nil | table<"'once'" | "'nested'", boolean>
function Split:on(event, handler, options)
  if not self._.mounted then
    error("split is not mounted yet. call split:mount()")
  end

  autocmd.buf.define(self.bufnr, event, handler, options)
end

---@param event nil | string | string[]
function Split:off(event)
  if not self._.mounted then
    error("split is not mounted yet. call split:mount()")
  end

  autocmd.buf.remove(self.bufnr, nil, event)
end

---@alias NuiSplit.constructor fun(options: table): NuiSplit
---@type NuiSplit|NuiSplit.constructor
local NuiSplit = Split

return NuiSplit
