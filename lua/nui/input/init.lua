local Popup = require("nui.popup")
local Text = require("nui.text")
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type
local event = require("nui.utils.autocmd").event

-- exiting insert mode places cursor one character backward,
-- so patch the cursor position to one character forward
-- when unmounting input.
---@param target_cursor number[]
---@param force? boolean
local function patch_cursor_position(target_cursor, force)
  local cursor = vim.api.nvim_win_get_cursor(0)

  if target_cursor[2] == cursor[2] and force then
    -- didn't exit insert mode yet, but it's gonna
    vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + 1 })
  elseif target_cursor[2] - 1 == cursor[2] then
    -- already exited insert mode
    vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + 1 })
  end
end

---@class nui_input_options
---@field prompt? string|NuiText
---@field default_value? string
---@field on_change? fun(value: string): nil
---@field on_close? fun(): nil
---@field on_submit? fun(value: string): nil

---@class nui_input_internal: nui_popup_internal
---@field default_value string
---@field prompt NuiText
---@field disable_cursor_position_patch boolean
---@field on_change? fun(value: string): nil
---@field on_close fun(): nil
---@field on_submit fun(value: string): nil
---@field pending_submit_value? string

---@class NuiInput: NuiPopup
---@field private _ nui_input_internal
local Input = Popup:extend("NuiInput")

---@param popup_options nui_popup_options
---@param options nui_input_options
function Input:init(popup_options, options)
  popup_options.enter = true

  popup_options.buf_options = defaults(popup_options.buf_options, {})
  popup_options.buf_options.buftype = "prompt"

  if not is_type("table", popup_options.size) then
    popup_options.size = {
      width = popup_options.size,
    }
  end

  popup_options.size.height = 1

  Input.super.init(self, popup_options)

  self._.default_value = defaults(options.default_value, "")
  self._.prompt = Text(defaults(options.prompt, ""))
  self._.disable_cursor_position_patch = defaults(options.disable_cursor_position_patch, false)

  self.input_props = {}

  self._.on_change = options.on_change
  self._.on_close = options.on_close or function() end
  self._.on_submit = options.on_submit or function() end
end

function Input:mount()
  local props = self.input_props

  if self._.mounted then
    return
  end

  Input.super.mount(self)

  if self._.on_change then
    ---@deprecated
    props.on_change = function()
      local value_with_prompt = vim.api.nvim_buf_get_lines(self.bufnr, 0, 1, false)[1]
      local value = string.sub(value_with_prompt, self._.prompt:length() + 1)
      self._.on_change(value)
    end

    vim.api.nvim_buf_attach(self.bufnr, false, {
      on_lines = props.on_change,
    })
  end

  ---@deprecated
  props.on_submit = function(value)
    self._.pending_submit_value = value
    self:unmount()
  end

  vim.fn.prompt_setcallback(self.bufnr, props.on_submit)

  -- @deprecated
  --- Use `input:unmount`
  ---@deprecated
  props.on_close = function()
    self:unmount()
  end

  vim.fn.prompt_setinterrupt(self.bufnr, props.on_close)

  vim.fn.prompt_setprompt(self.bufnr, self._.prompt:content())

  self:on(event.InsertEnter, function()
    if #self._.default_value then
      vim.api.nvim_feedkeys(self._.default_value, "n", true)
    end

    if self._.prompt:length() > 0 then
      vim.schedule(function()
        self._.prompt:highlight(self.bufnr, self.ns_id, 1, 0)
      end)
    end
  end, { once = true })

  vim.api.nvim_command("startinsert!")
end

function Input:unmount()
  if not self._.mounted then
    return
  end

  local container_winid = self._.container_info.winid
  local target_cursor = vim.api.nvim_win_is_valid(container_winid) and vim.api.nvim_win_get_cursor(container_winid)
    or nil
  local prompt_mode = vim.fn.mode()

  Input.super.unmount(self)

  if self._.loading then
    return
  end

  self._.loading = true

  local pending_submit_value = self._.pending_submit_value

  vim.schedule(function()
    -- NOTE: on prompt-buffer normal mode <CR> causes neovim to enter insert mode.
    --  ref: https://github.com/neovim/neovim/blob/d8f5f4d09078/src/nvim/normal.c#L5327-L5333
    if (pending_submit_value and prompt_mode == "n") or prompt_mode == "i" then
      vim.api.nvim_command("stopinsert")
    end

    if not self._.disable_cursor_position_patch and target_cursor ~= nil then
      patch_cursor_position(target_cursor, pending_submit_value and prompt_mode == "n")
    end

    if pending_submit_value then
      self._.pending_submit_value = nil
      self._.on_submit(pending_submit_value)
    else
      self._.on_close()
    end
    self._.loading = false
  end)
end

---@alias NuiInput.constructor fun(popup_options: nui_popup_options, options: nui_input_options): NuiInput
---@type NuiInput|NuiInput.constructor
local NuiInput = Input

return NuiInput
