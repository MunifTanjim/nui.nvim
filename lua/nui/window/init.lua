local Border = require("nui.window.border")
local cleanup = require("nui.window.cleanup")
local keymaps = require("nui.window.keymaps")
local utils = require("nui.utils")
local is_type = utils.is_type

local function get_container_info(config)
  local relative = config.relative

  if relative == "editor" then
    return {
      relative = relative,
      size = utils.get_editor_size(),
      type = "editor"
    }
  end

  local winid = config.win

  if relative == "cursor" or relative == "win" then
    return {
      relative = relative,
      size = utils.get_window_size(winid),
      type = "window",
    }
  end
end

local function calculate_window_size(size, container)
  local width
  local height

  if is_type("table", size) then
    local w = utils.parse_number_input(size.width)
    assert(w.value ~= nil, "invalid size.width")
    if w.is_percentage then
      width = math.floor(container.size.width * w.value)
    else
      width = w.value
    end

    local h = utils.parse_number_input(size.height)
    assert(h.value ~= nil, "invalid size.height")
    if h.is_percentage then
      height = math.floor(container.size.height * h.value)
    else
      height = h.value
    end
  else
    local n = utils.parse_number_input(size)
    assert(n.value ~= nil, "invalid size")
    if n.is_percentage then
      width = math.floor(container.size.width * n.value)
      height = math.floor(container.size.height * n.value)
    else
      width = n.value
      height = n.value
    end
  end

  return {
    width = width,
    height = height,
  }
end

local function calculate_window_position(position, size, container)
  local row
  local col

  if is_type("table", position) then
    local r = utils.parse_number_input(position.row)
    assert(r.value ~= nil, "invalid position.row")
    if r.is_percentage then
      assert(container.relative ~= "cursor", "% position can not be used relative to cursor")
      row = math.floor((container.size.height - size.height) * r.value)
    else
      row = r.value
    end

    local c = utils.parse_number_input(position.col)
    assert(c.value ~= nil, "invalid position.col")
    if c.is_percentage then
      assert(container.relative ~= "cursor", "% position can not be used relative to cursor")
      col = math.floor((container.size.width - size.width) * c.value)
    else
      col = c.value
    end
  else
    local n = utils.parse_number_input(position)
    assert(n.value ~= nil, "invalid position")
    if n.is_percentage then
      assert(container.relative ~= "cursor", "% position can not be used relative to cursor")
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

local function calculate_winblend(opacity)
  assert(is_type("number", opacity), "invalid opacity")
  assert(0 <= opacity, "opacity must be equal or greater than 0")
  assert(opacity <= 1, "opacity must be equal or lesser than 0")
  return 100 - (opacity * 100)
end

local Window = {}

function Window:new(opts)
  local window = {
    bufnr = opts.bufnr,
    config = {
      _enter = utils.defaults(opts.enter, false),
      relative = "editor",
      style = "minimal",
      zindex = utils.defaults(opts.zindex, 50),
    },
    options = {
      winblend = calculate_winblend(utils.defaults(opts.opacity, 1)),
      winhighlight = opts.highlight,
    },
  }

  setmetatable(window, self)
  self.__index = self

  if is_type("table", opts.relative) then
    window.config.relative = "win"
    window.config.win = opts.relative.winid or 0
  elseif is_type("string", opts.relative) then
    window.config.relative = opts.relative
  end

  local container_info = get_container_info(window.config)
  window.size = calculate_window_size(opts.size, container_info)
  window.position = calculate_window_position(opts.position, window.size, container_info)
  window.border = Border:new(window, opts.border)

  window.config.width = window.size.width
  window.config.height = window.size.height
  window.config.row = window.position.row
  window.config.col = window.position.col
  window.config.border = window.border:get()

  return window
end

function Window:mount()
  self.border:mount()

  if not self.bufnr then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    assert(self.bufnr, "failed to create buffer")
  end

  local enter = self.config._enter
  self.config._enter = nil
  self.winid = vim.api.nvim_open_win(self.bufnr, enter, self.config)
  assert(self.winid, "failed to create window")

  for name, value in pairs(self.options) do
    if not is_type("nil", value) then
      vim.api.nvim_win_set_option(self.winid, name, value)
    end
  end

  cleanup.register(self.bufnr, { self.winid, self.border.winid })
end

function Window:unmount()
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end
end

---@param event_name "'lines'" | "'bytes'" | "'changedtick'" | "'detach'" | "'reload'"
function Window:on(event_name, handler)
  if not self.bufnr then
    error("window is not mounted yet. call window:mount()")
  end

  if not self._event_handler then
    self._event_handler = {}

    local function event_handler(name, ...)
      if self._event_handler[name] then
        self._event_handler[name](name, ...)
      end
    end

    vim.api.nvim_buf_attach(self.bufnr, false, {
      on_lines = event_handler,
      on_bytes = event_handler,
      on_changedtick = event_handler,
      on_detach = event_handler,
      on_reload = event_handler,
    })
  end

  if self._event_handler[event_name] then
    return error(
      string.format("handler already registered for event: %s", event_name)
    )
  end

  if not is_type("function", handler) then
    return error("handler must be function")
  end

  self._event_handler[event_name] = handler
end

-- set keymap for this window. if keymap was already set and
-- `force` is not `true` returns `false`, otherwise returns `true`
---@param mode "'i'" | "'n'"
---@param key string
---@param handler any
---@param opts table<"'expr'" | "'noremap'" | "'nowait'" | "'script'" | "'silent'" | "'unique'", boolean>
---@param force boolean
---@return boolean ok
function Window:map(mode, key, handler, opts, force)
  if not self.bufnr then
    error("window is not mounted yet. call window:mount()")
  end

  return keymaps.set(self.bufnr, mode, key, handler, opts, force)
end

return Window
