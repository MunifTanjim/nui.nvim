local Animation = require("nui.animation")
local Object = require("nui.object")
local NuiText = require("nui.text")
local presets = require("nui.spinner.preset")
local defaults = require("nui.utils").defaults

---@class nui_spinner_options
---@field animation? string|{ frame: string[], interval: integer } preset name, or a custom { frame, interval } table
---@field hl? string highlight group for the glyph
---@field cycle? integer number of loops to play, then stop on the last frame (default: loop forever)

---@class NuiSpinner
---@field private _animation NuiAnimation
---@field private _hl? string
local Spinner = Object("NuiSpinner")

---@param options? nui_spinner_options
function Spinner:init(options)
  options = options or {}

  local animation = defaults(options.animation, "dots")

  local def
  if type(animation) == "string" then
    def = presets[animation] or error("nui.spinner: unknown preset '" .. animation .. "'")
  elseif type(animation) == "table" then
    if type(animation.frame) ~= "table" or #animation.frame == 0 then
      error("nui.spinner: custom `animation` needs a non-empty `frame` list")
    end
    if type(animation.interval) ~= "number" or animation.interval <= 0 then
      error("nui.spinner: custom `animation` needs a positive `interval`")
    end
    def = animation
  else
    error("nui.spinner: `animation` must be a preset name or a table")
  end

  self._animation = Animation({ frame = def.frame, interval = def.interval, cycle = options.cycle })
  self._hl = options.hl
end

---@return NuiSpinner
function Spinner:next()
  self._animation:next()
  return self
end

---@return NuiSpinner
function Spinner:reset()
  self._animation:reset()
  return self
end

---@return NuiText
function Spinner:text()
  return NuiText(self._animation:frame(), self._hl)
end

---@class nui_spinner_start_options
---@field on_stop? fun(spinner: NuiSpinner): nil called once when the running timer stops

---Run a timer that advances the frame every `interval` ms and calls `on_tick` on
---the main loop after each advance. To drive advancement yourself (without a
---timer), use `next` instead. Calling `start` again restarts.
---
---With a `cycle` count, the timer stops itself after the last frame of the last
---cycle. `opts.on_stop` (if given) fires once when the running timer stops,
---whether from finishing its cycles or from a `stop()` call. It does not fire on
---restart.
---@param on_tick fun(spinner: NuiSpinner): nil
---@param opts? nui_spinner_start_options
---@return NuiSpinner
function Spinner:start(on_tick, opts)
  if type(on_tick) ~= "function" then
    error("nui.spinner: `on_tick` must be a function")
  end
  if opts ~= nil and type(opts) ~= "table" then
    error("nui.spinner: `opts` must be a table")
  end
  opts = opts or {}
  local on_stop = opts.on_stop
  if on_stop ~= nil and type(on_stop) ~= "function" then
    error("nui.spinner: `on_stop` must be a function")
  end

  self._animation:start(function()
    on_tick(self)
  end, {
    on_stop = on_stop and function()
      on_stop(self)
    end or nil,
  })

  return self
end

---Stop the timer. Idempotent.
---@return NuiSpinner
function Spinner:stop()
  self._animation:stop()

  return self
end

---@alias NuiSpinner.constructor fun(options?: nui_spinner_options): NuiSpinner
---@type NuiSpinner|NuiSpinner.constructor
local NuiSpinner = Spinner

return NuiSpinner
