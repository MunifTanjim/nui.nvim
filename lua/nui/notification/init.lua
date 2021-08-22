local NotificationCtl = require("nui.notification.controller")
local Popup = require("nui.popup")
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type
local utils = require("nui.utils")

-- Emulate a set to denote valid values
local position_texts = {
  topleft = true,
  topright = true,
  botright = true,
  botleft = true,
}

local Notification = setmetatable({
  name = "Notification",
  super = Popup,
}, {
  __index = Popup.__index,
})

local function trim_notification_lines(lines)
  if not is_type("table", lines) then
    lines = { lines }
  end

  local editor_cfg = utils.get_editor_size({ height = -4 })
  local allowed_width = math.floor(editor_cfg.width * 0.3)
  local allowed_height = math.floor(editor_cfg.height * 0.3)
  local max_width, filtered = 1, {}
  local modified

  for i, line in ipairs(lines) do
    if i >= allowed_height then
      table.insert(filtered, "…")
      break
    end

    if #line >= allowed_width then
      modified = utils._.truncate_text(line, allowed_width - 3)
    else
      modified = line
    end

    if #modified > max_width then
      max_width = #modified
    end

    table.insert(filtered, modified)
  end

  return {
    text = filtered,
    width = max_width,
    height = #filtered,
  }
end

local function calculate_window_position_from_text(text, width, height, is_complex)
  assert(position_texts[text], "invalid notification position: " .. text)

  local wincfg = {
    width = math.max(width, 1),
    height = math.max(height, 1),
    row = nil,
    col = nil,
  }

  -- TODO: Smarter about signcolumn, tabline, statusline, cmdheight, etc.
  local editor_cfg = utils.get_editor_size({ height = -4 })

  -- Top-left of the editor is (0, 0)
  if text == "topleft" then
    wincfg.row = 1
    wincfg.col = 1
  elseif text == "topright" then
    wincfg.row = 1
    wincfg.col = editor_cfg.width - wincfg.width - 1
  elseif text == "botleft" then
    -- FIXME: The `+2` "assumes" a complex border, shouldn't be needed in an ideal case
    wincfg.row = editor_cfg.height - wincfg.height + (is_complex and 1 or 0)
    wincfg.col = 1
  else
    -- FIXME: The `+2` "assumes" a complex border, shouldn't be needed in an ideal case
    wincfg.row = editor_cfg.height - wincfg.height + (is_complex and 1 or 0)
    wincfg.col = editor_cfg.width - wincfg.width - 1
  end

  return wincfg
end

local function init(class, popup_options, options)
  popup_options.enter = false
  popup_options.focusable = false
  popup_options.buf_options = defaults(popup_options.buf_options, {})
  popup_options.buf_options.buftype = "nofile"

  -- TODO: Support window-relative positioning by updating below function call
  popup_options.relative = "editor"

  local _border = popup_options.border
  local is_complex = _border.text or _border.padding

  local trimmed = trim_notification_lines(options.text)
  local position = calculate_window_position_from_text(options.position, trimmed.width, trimmed.height, is_complex)

  popup_options.position = {}
  popup_options.position.row = position.row
  popup_options.position.col = position.col

  popup_options.size = {}
  popup_options.size.height = position.height
  popup_options.size.width = position.width

  local self = class.super.init(class, popup_options)

  self.notification_options = {
    timeout = (math.floor(options.timeout) or 3) * 1000,
    text = trimmed.text,
    showmess = options.showmess,
    position_text = options.position,
  }

  return self
end

function Notification:init(popup_options, options)
  return init(self, popup_options, options)
end

function Notification:mount()
  self.super.mount(self)

  NotificationCtl.move_notification_windows(self)
  NotificationCtl.add_active_notification(self)

  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, self.notification_options.text)

  vim.fn.timer_start(self.notification_options.timeout, function()
    NotificationCtl.remove_active_notification(self.notification_options.position_text, self)
  end)

  if self.notification_options.showmess then
    vim.schedule(function()
      -- Echo individually to (hopefully) avoid "Press Enter to continue" prompts
      for _, line in ipairs(self.notification_options.text) do
        vim.api.nvim_echo({ { line } }, true, {})
      end
    end)
  end
end

local NotificationClass = setmetatable({
  __index = Notification,
}, {
  __call = init,
  __index = Notification,
})

return NotificationClass
