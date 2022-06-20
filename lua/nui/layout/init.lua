local utils = require("nui.utils")
local layout_utils = require("nui.layout.utils")

local _ = utils._

local defaults = utils.defaults
local is_type = utils.is_type
local calculate_window_position = layout_utils.calculate_window_position
local calculate_window_size = layout_utils.calculate_window_size
local get_container_info = layout_utils.get_container_info
local parse_relative = layout_utils.parse_relative

-- GitHub Issue: https://github.com/neovim/neovim/issues/18925
local function apply_workaround_for_float_relative_position_issue_18925(layout)
  local current_winid = vim.api.nvim_get_current_win()

  vim.api.nvim_set_current_win(layout.winid)
  vim.api.nvim_command("redraw!")
  vim.api.nvim_set_current_win(current_winid)
end

local function merge_default_options(options)
  options.relative = defaults(options.relative, "win")

  return options
end

local function normalize_options(options)
  options = _.normalize_layout_options(options)

  return options
end

---@param class NuiLayout
---@return NuiLayout
local function init(class, options, box)
  ---@type NuiLayout
  local self = setmetatable({}, { __index = class })

  options = merge_default_options(options)
  options = normalize_options(options)

  self._ = {
    box = class.Box(box),
    loading = false,
    mounted = false,
    win_enter = false,
    win_config = {
      focusable = false,
      style = "minimal",
      zindex = 49,
    },
  }

  local win_config = self._.win_config

  self._.position = vim.tbl_extend(
    "force",
    self._._position or {},
    parse_relative(options.relative, vim.api.nvim_get_current_win())
  )
  win_config.relative = self._.position.relative
  win_config.win = self._.position.relative == "win" and self._.position.win or nil
  win_config.bufpos = self._.position.bufpos

  local container_info = get_container_info(self._.position)

  self._.size = calculate_window_size(options.size, container_info.size)
  win_config.width = self._.size.width
  win_config.height = self._.size.height

  self._.position = vim.tbl_extend(
    "force",
    self._.position,
    calculate_window_position(options.position, self._.size, container_info)
  )
  win_config.row = self._.position.row
  win_config.col = self._.position.col

  return self
end

---@class NuiLayout
local Layout = setmetatable({
  super = nil,
}, {
  __call = init,
  __name = "NuiLayout",
})

local function get_child_position(canvas_position, current_position, box_dir)
  if box_dir == "row" then
    return {
      row = canvas_position.row,
      col = current_position.col,
    }
  elseif box_dir == "col" then
    return {
      col = canvas_position.col,
      row = current_position.row,
    }
  end
end

local function get_child_size(child, canvas_size)
  local outer_size = calculate_window_size(child.size, canvas_size)
  local inner_size = {
    width = outer_size.width,
    height = outer_size.height,
  }

  if child.component then
    if child.component.border then
      inner_size.width = inner_size.width - child.component.border._.size_delta.width
      inner_size.height = inner_size.height - child.component.border._.size_delta.height
    end
  end

  return outer_size, inner_size
end

local function process_layout(box, meta)
  if box.mount or box.component or not box.box then
    return error("invalid paramter: box")
  end

  local canvas_size = meta.canvas_size
  if not is_type("number", canvas_size.width) or not is_type("number", canvas_size.height) then
    return error("invalid value: box.size")
  end

  local current_position = {
    col = 0,
    row = 0,
  }

  for _, child in ipairs(box.box) do
    local position = get_child_position(meta.position, current_position, box.dir)
    local outer_size, inner_size = get_child_size(child, canvas_size)

    if child.component then
      child.component:set_layout({
        size = inner_size,
        relative = {
          type = "win",
          winid = meta.winid,
        },
        position = position,
      })
    else
      process_layout(child, {
        winid = meta.winid,
        canvas_size = outer_size,
        position = position,
      })
    end

    current_position.col = current_position.col + outer_size.width
    current_position.row = current_position.row + outer_size.height
  end
end

local function mount_box(box)
  for _, child in ipairs(box.box) do
    if child.component then
      child.component:mount()
    else
      mount_box(child)
    end
  end
end

function Layout:mount()
  if self._.loading or self._.mounted then
    return
  end

  self._.loading = true

  if not self.bufnr then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    assert(self.bufnr, "failed to create buffer")
  end

  self.winid = vim.api.nvim_open_win(self.bufnr, self._.win_enter, self._.win_config)
  assert(self.winid, "failed to create popup window")

  apply_workaround_for_float_relative_position_issue_18925(self)

  local root_box = self._.box

  process_layout(root_box, {
    winid = self.winid,
    canvas_size = self._.size,
    position = {
      row = 0,
      col = 0,
    },
  })

  mount_box(root_box)

  self._.loading = false
  self._.mounted = true
end

local function unmount_box(box)
  for _, child in ipairs(box.box) do
    if child.component then
      child.component:unmount()
    else
      unmount_box(child)
    end
  end
end

function Layout:unmount()
  if self._.loading or not self._.mounted then
    return
  end

  self._.loading = true

  local root_box = self._.box

  unmount_box(root_box)

  if self.bufnr then
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
    self.bufnr = nil
  end

  if vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end
  self.winid = nil

  self._.loading = false
  self._.mounted = false
end

function Layout.Box(box, options)
  options = options or {}

  if box.mount then
    return {
      component = box,
      size = options.size,
    }
  end

  if box.dir then
    return box
  end

  local dir = defaults(options.dir, "row")

  -- normalize children size
  for _, child in ipairs(box) do
    if not child.size then
      error("missing child.size")
    end

    if dir == "row" then
      if not is_type("table", child.size) then
        child.size = { width = child.size }
      end
      if not child.size.height then
        child.size.height = "100%"
      end
    elseif dir == "col" then
      if not is_type("table", child.size) then
        child.size = { height = child.size }
      end
      if not child.size.width then
        child.size.width = "100%"
      end
    end
  end

  return {
    box = box,
    dir = dir,
    size = options.size,
  }
end

---@alias NuiLayout.constructor fun(options: table, box: table): NuiLayout
---@type NuiLayout|NuiLayout.constructor
local NuiLayout = Layout

return NuiLayout
