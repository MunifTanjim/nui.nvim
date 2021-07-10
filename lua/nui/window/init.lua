local Border = require("nui.window.border")
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

  local window_id = config.win

  if relative == "cursor" or relative == "win" then
    return {
      relative = relative,
      size = utils.get_window_size(window_id),
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

local Window = {
  __related_window_ids_by_bufnr = {}
}

local function register_cleanup(bufnr, window_ids)
  Window.__related_window_ids_by_bufnr[bufnr] = window_ids

  vim.api.nvim_exec(
    string.format(
      "autocmd WinLeave,BufLeave,BufDelete <buffer=%s> ++once ++nested lua require('nui.window').do_cleanup(%s)",
      bufnr,
      bufnr
    ),
    false
  )
end

function Window.do_cleanup(bufnr)
  local window_ids = Window.__related_window_ids_by_bufnr[bufnr]

  Window.__related_window_ids_by_bufnr[bufnr] = nil

  if not utils.is_type("table", window_ids) then
    return
  end

  for _, win_id in ipairs(window_ids) do
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, true)
    end
  end
end

function Window:new(opts)
  local window = {}

  setmetatable(window, self)
  self.__index = self

  window.config = {
    style = "minimal",
    relative = "editor",
  }

  if is_type("table", opts.relative) then
    window.config.relative = "win"
    window.config.win = opts.relative.window_id or 0
  elseif is_type("string", opts.relative) then
    window.config.relative = opts.relative
  end

  local container_info = get_container_info(window.config)
  window.size = calculate_window_size(opts.size, container_info)
  window.position = calculate_window_position(opts.position, window.size, container_info)
  window.zindex = utils.defaults(opts.zindex, 50)
  window.border = Border:new(window, opts.border)

  window.config.width = window.size.width
  window.config.height = window.size.height
  window.config.row = window.position.row - 1
  window.config.col = window.position.col - 1
  window.config.border = window.border:get()

  local enter = utils.defaults(opts.enter, true)
  local winblend = calculate_winblend(utils.defaults(opts.opacity, 1))

  window.bufnr = opts.bufnr or vim.api.nvim_create_buf(false, true)
  assert(window.bufnr, "failed to create buffer")

  window.winid = vim.api.nvim_open_win(window.bufnr, enter, window.config)
  assert(window.winid, "failed to create window")

  vim.api.nvim_win_set_option(window.winid, 'winblend', winblend)

  register_cleanup(window.bufnr, { window.winid, window.border.winid })

  return window
end

return Window
