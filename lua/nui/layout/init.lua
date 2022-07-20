local Object = require("nui.object")
local utils = require("nui.utils")
local layout_utils = require("nui.layout.utils")

local _ = utils._

local defaults = utils.defaults
local is_type = utils.is_type
local calculate_window_size = layout_utils.calculate_window_size
local u = {
  size = layout_utils.size,
  position = layout_utils.position,
  update_layout_config = layout_utils.update_layout_config,
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

local function is_component(object)
  return object and object.mount
end

local function is_component_mounted(component)
  return is_type("number", component.winid)
end

local function get_layout_config_relative_to_component(component)
  return {
    relative = { type = "win", winid = component.winid },
    position = { row = 0, col = 0 },
    size = { width = "100%", height = "100%" },
  }
end

---@class NuiLayout
local Layout = Object("NuiLayout")

function Layout:init(options, box)
  local container
  if is_component(options) then
    container = options
    options = get_layout_config_relative_to_component(container)
  else
    options = merge_default_options(options)
    options = normalize_options(options)
  end

  self._ = {
    box = Layout.Box(box),
    container = container,
    layout = {},
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

  if not is_component(container) or is_component_mounted(container) then
    self:update(options)
  end
end

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
---@param growable_dimension_per_factor? number
local function get_child_size(parent, child, container_size, growable_dimension_per_factor)
  local child_size = {
    width = child.size.width,
    height = child.size.height,
  }

  if child.grow and growable_dimension_per_factor then
    if parent.dir == "col" then
      child_size.height = math.floor(growable_dimension_per_factor * child.grow)
    else
      child_size.width = math.floor(growable_dimension_per_factor * child.grow)
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

  local growable_child_factor = 0

  for _, child in ipairs(box.box) do
    if meta.process_growable_child or not child.grow then
      local position = get_child_position(meta.position, current_position, box.dir)
      local outer_size, inner_size = get_child_size(box, child, canvas_size, meta.growable_dimension_per_factor)

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
      growable_child_factor = growable_child_factor + child.grow
    end
  end

  if meta.process_growable_child or growable_child_factor == 0 then
    return
  end

  local growable_width = canvas_size.width - current_position.col
  local growable_height = canvas_size.height - current_position.row
  local growable_dimension = box.dir == "col" and growable_height or growable_width
  local growable_dimension_per_factor = growable_dimension / growable_child_factor

  process_layout(box, {
    winid = meta.winid,
    canvas_size = meta.canvas_size,
    position = meta.position,
    process_growable_child = true,
    growable_dimension_per_factor = growable_dimension_per_factor,
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

  local container = self._.container
  if is_component(container) and not is_component_mounted(container) then
    container:mount()
    self:update(get_layout_config_relative_to_component(container))
  end

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

function Layout:update(config, box)
  config = config or {}

  if not box and is_box(config) or is_box(config[1]) then
    box = config
    config = {}
  end

  u.update_layout_config(self, config)

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
