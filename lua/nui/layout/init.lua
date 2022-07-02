local utils = require("nui.utils")
local layout_utils = require("nui.layout.utils")

local _ = utils._

local defaults = utils.defaults
local is_type = utils.is_type
local calculate_window_position = layout_utils.calculate_window_position
local calculate_window_size = layout_utils.calculate_window_size
local get_container_info = layout_utils.get_container_info
local parse_relative = layout_utils.parse_relative
local u = {
  size = layout_utils.size,
  position = layout_utils.position,
}

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

local function is_box(object)
  return object and (object.box or object.component)
end

---@param class NuiLayout
---@return NuiLayout
local function init(class, options, box)
  ---@type NuiLayout
  local self = setmetatable({}, { __index = class })

  options = merge_default_options(options)
  options = normalize_options(options)

  self._ = {
    layout = {
      relative = options.relative,
      size = options.size,
      position = options.position,
    },
    loading = false,
    mounted = false,
    win_enter = false,
    win_config = {
      focusable = false,
      style = "minimal",
      zindex = 49,
    },
    win_options = {
      winblend = 100,
    },
  }

  self:update(options, box)

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

---@param parent table Layout.Box
---@param child table Layout.Box
---@param container_size table
---@param growable_child_dimension? number
local function get_child_size(parent, child, container_size, growable_child_dimension)
  local child_size = {
    width = child.size.width,
    height = child.size.height,
  }

  if child.grow and growable_child_dimension then
    if parent.dir == "col" then
      child_size.height = growable_child_dimension
    else
      child_size.width = growable_child_dimension
    end
  end

  local outer_size = calculate_window_size(child_size, container_size)

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

  local growable_child_count = 0

  for _, child in ipairs(box.box) do
    if meta.process_growable_child or not child.grow then
      local position = get_child_position(meta.position, current_position, box.dir)
      local outer_size, inner_size = get_child_size(box, child, canvas_size, meta.growable_child_dimension)

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

    if child.grow then
      growable_child_count = growable_child_count + 1
    end
  end

  if meta.process_growable_child or growable_child_count == 0 then
    return
  end

  local growable_width = canvas_size.width - current_position.col
  local growable_height = canvas_size.height - current_position.row
  local growable_dimension = box.dir == "col" and growable_height or growable_width
  local growable_child_dimension = math.floor(growable_dimension / growable_child_count)

  process_layout(box, {
    winid = meta.winid,
    canvas_size = meta.canvas_size,
    position = meta.position,
    process_growable_child = true,
    growable_child_dimension = growable_child_dimension,
  })
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

function Layout:_process_layout()
  apply_workaround_for_float_relative_position_issue_18925(self)

  process_layout(self._.box, {
    winid = self.winid,
    canvas_size = self._.size,
    position = {
      row = 0,
      col = 0,
    },
  })
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

  _.set_win_options(self.winid, self._.win_options)

  self:_process_layout()

  mount_box(self._.box)

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

function Layout:_update_config_relative()
  local fallback_winid = self._.position and self._.position.win or vim.api.nvim_get_current_win()
  self._.position = vim.tbl_extend(
    "force",
    self._._position or {},
    parse_relative(self._.layout.relative, fallback_winid)
  )

  self._.win_config.relative = self._.position.relative
  self._.win_config.win = self._.position.relative == "win" and self._.position.win or nil
  self._.win_config.bufpos = self._.position.bufpos
end

function Layout:_update_config_size()
  self._.size = calculate_window_size(self._.layout.size, self._.container.size)

  self._.win_config.width = self._.size.width
  self._.win_config.height = self._.size.height
end

function Layout:_update_config_position()
  self._.position = vim.tbl_extend(
    "force",
    self._.position,
    calculate_window_position(self._.layout.position, self._.size, self._.container)
  )

  self._.win_config.row = self._.position.row
  self._.win_config.col = self._.position.col
end

function Layout:update(config, box)
  config = config or {}

  if not box and is_box(config) or is_box(config[1]) then
    box = config
    config = {}
  end

  local options = _.normalize_layout_options({
    relative = config.relative,
    size = config.size,
    position = config.position,
  })

  local win_config = self._.win_config

  if options.relative then
    self._.layout.relative = options.relative
    self:_update_config_relative()
  end

  local prev_container_size = self._.container and self._.container.size
  self._.container = get_container_info(self._.position)
  local container_size_changed = not u.size.are_same(self._.container.size, prev_container_size)

  local need_size_refresh = container_size_changed
    and self._.layout.size
    and u.size.contains_percentage_string(self._.layout.size)

  if options.size or need_size_refresh then
    self._.layout.size = options.size or self._.layout.size
    self:_update_config_size()
  end

  if not win_config.width or not win_config.height then
    return error("missing layout config: size")
  end

  local need_position_refresh = container_size_changed
    and self._.layout.position
    and u.position.contains_percentage_string(self._.layout.position)

  if options.position or need_position_refresh then
    self._.layout.position = options.position or self._.layout.position
    self:_update_config_position()
  end

  if not win_config.row or not win_config.col then
    return error("missing layout config: position")
  end

  if box then
    self._.box = Layout.Box(box)
  end

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self._.win_config)
    self:_process_layout()
  end
end

function Layout.Box(box, options)
  options = options or {}

  if is_box(box) then
    return box
  end

  if box.mount then
    return {
      component = box,
      grow = options.grow,
      size = options.size,
    }
  end

  local dir = defaults(options.dir, "row")

  -- normalize children size
  for _, child in ipairs(box) do
    if not child.grow and not child.size then
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
    grow = options.grow,
    size = options.size,
  }
end

---@alias NuiLayout.constructor fun(options: table, box: table): NuiLayout
---@type NuiLayout|NuiLayout.constructor
local NuiLayout = Layout

return NuiLayout
