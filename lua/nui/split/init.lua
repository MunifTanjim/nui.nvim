local Object = require("nui.object")
local buf_storage = require("nui.utils.buf_storage")
local autocmd = require("nui.utils.autocmd")
local keymap = require("nui.utils.keymap")
local utils = require("nui.utils")
local split_utils = require("nui.split.utils")

local u = {
  clear_namespace = utils._.clear_namespace,
  normalize_namespace_id = utils._.normalize_namespace_id,
  split = split_utils,
}

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

--luacheck: push no max line length

---@alias nui_split_internal_position "'top'"|"'right'"|"'bottom'"|"'left'"
---@alias nui_split_internal_relative { type: "'editor'"|"'win'", win: number }
---@alias nui_split_internal_size { width?: number, height?: number }
---@alias nui_split_internal { loading: boolean, mounted: boolean, buf_options: table<string,any>, win_options: table<string,any>, position: nui_split_internal_position, relative: nui_split_internal_relative, size: nui_split_internal_size }

--luacheck: pop

---@class NuiSplit
---@field private _ nui_split_internal
---@field bufnr integer
---@field ns_id integer
---@field winid number
local Split = Object("NuiSplit")

---@param options table
function Split:init(options)
  options = u.split.merge_default_options(options)
  options = u.split.normalize_options(options)

  self._ = {
    enter = options.enter,
    buf_options = options.buf_options,
    loading = false,
    mounted = false,
    layout = {
      size = options.size,
    },
    position = options.position,
    relative = u.split.parse_relative(options.relative, 0),
    size = {},
    win_options = options.win_options,
    win_config = {},
  }

  self.ns_id = u.normalize_namespace_id(options.ns_id)

  self:_buf_create()

  local container_info = u.split.get_container_info(self._.relative)
  self._.size = u.split.calculate_window_size(self._.position, self._.layout.size, container_info.size)
  self._.win_config.width = self._.size.width
  self._.win_config.height = self._.size.height
end

function Split:_open_window()
  if self.winid or not self.bufnr then
    return
  end

  self.winid = vim.api.nvim_win_call(self._.relative.win, function()
    vim.api.nvim_command(
      string.format(
        "silent noswapfile %s %ssplit",
        split_direction_command_map[self._.relative.type][self._.position],
        self._.size.width or self._.size.height or ""
      )
    )

    return vim.api.nvim_get_current_win()
  end)

  vim.api.nvim_win_set_buf(self.winid, self.bufnr)

  if self._.enter then
    vim.api.nvim_set_current_win(self.winid)
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

function Split:_buf_create()
  if not self.bufnr then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    assert(self.bufnr, "failed to create buffer")
  end
end

function Split:mount()
  if self._.loading or self._.mounted then
    return
  end

  self._.loading = true

  self:_buf_create()

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

function Split:_buf_destroy()
  buf_storage.cleanup(self.bufnr)

  u.clear_namespace(self.bufnr, self.ns_id)

  if self.bufnr then
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end

    self.bufnr = nil
  end
end

function Split:unmount()
  if self._.loading or not self._.mounted then
    return
  end

  self._.loading = true

  self:_buf_destroy()

  self:_close_window()

  self._.loading = false
  self._.mounted = false
end

-- set keymap for this split
-- `force` is not `true` returns `false`, otherwise returns `true`
---@param mode string check `:h :map-modes`
---@param key string|string[] key for the mapping
---@param handler string | fun(): nil handler for the mapping
---@param opts table<"'expr'"|"'noremap'"|"'nowait'"|"'remap'"|"'script'"|"'silent'"|"'unique'", boolean>
---@return nil
function Split:map(mode, key, handler, opts, force)
  if not self.bufnr then
    error("split buffer not found.")
  end

  return keymap.set(self.bufnr, mode, key, handler, opts, force)
end

---@param mode string check `:h :map-modes`
---@param key string|string[] key for the mapping
---@return nil
function Split:unmap(mode, key)
  if not self.bufnr then
    error("split buffer not found.")
  end

  return keymap._del(self.bufnr, mode, key)
end

---@param event string | string[]
---@param handler string | function
---@param options nil | table<"'once'" | "'nested'", boolean>
function Split:on(event, handler, options)
  if not self.bufnr then
    error("split buffer not found.")
  end

  autocmd.buf.define(self.bufnr, event, handler, options)
end

---@param event nil | string | string[]
function Split:off(event)
  if not self.bufnr then
    error("split buffer not found.")
  end

  autocmd.buf.remove(self.bufnr, nil, event)
end

---@alias NuiSplit.constructor fun(options: table): NuiSplit
---@type NuiSplit|NuiSplit.constructor
local NuiSplit = Split

return NuiSplit
