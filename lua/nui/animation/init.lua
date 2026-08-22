local Object = require("nui.object")
local easings = require("nui.animation.easing")
local defaults = require("nui.utils").defaults

local uv = vim.uv or vim.loop

---@param value string|fun(t: number): number
---@return fun(t: number): number
local function resolve_easing(value)
  if type(value) == "function" then
    return value
  end
  if type(value) == "string" then
    return easings[value] or error("nui.animation: unknown easing '" .. value .. "'")
  end
  error("nui.animation: `easing` must be a preset name or a function")
end

---@class nui_animation_options
---@field frame any[]|fun(t: number): any frames list (cycle) or fn mapping progress 0..1 to a frame (timeline)
---@field interval? integer milliseconds per step; required for :next()/:start() and to :seek() a list frame
---@field duration? integer milliseconds per loop (required when `frame` is a function)
---@field easing? string|fun(t: number): number easing preset name or function (default linear; optional for a list)
---@field cycle? integer number of loops to play, then stop on the last frame (default: loop forever)

---@class NuiAnimation
---@field private _frames? any[]
---@field private _frame_count? integer
---@field private _generate? fun(t: number): any
---@field private _duration? number
---@field private _easing? fun(t: number): number
---@field private _interval? integer
---@field private _cycle? integer
---@field private _elapsed integer
---@field private _frame? any
---@field private _completed boolean
---@field private _timer? uv_timer_t
---@field private _on_stop? fun(animation: NuiAnimation): nil
local Animation = Object("NuiAnimation")

---@param options? nui_animation_options
function Animation:init(options)
  options = options or {}

  local frame = options.frame

  if type(frame) == "function" then
    local duration = options.duration
    if type(duration) ~= "number" or duration <= 0 then
      error("nui.animation: `duration` must be a positive number")
    end

    self._generate = frame
    self._duration = duration
    self._easing = resolve_easing(defaults(options.easing, "linear"))
  elseif type(frame) == "table" and #frame > 0 then
    self._frames = frame
    self._frame_count = #frame
    if options.easing ~= nil then
      self._easing = resolve_easing(options.easing)
    end
  else
    error("nui.animation: `frame` must be a non-empty array or a function")
  end

  local interval = options.interval
  if interval ~= nil and (type(interval) ~= "number" or interval <= 0) then
    error("nui.animation: `interval` must be a positive number")
  end
  self._interval = interval

  local cycle = options.cycle
  if cycle ~= nil and (type(cycle) ~= "number" or cycle <= 0 or cycle % 1 ~= 0) then
    error("nui.animation: `cycle` must be a positive integer")
  end
  self._cycle = cycle

  self:reset()
end

---@return any
function Animation:frame()
  return self._frame
end

---@private
---@param what string
---@return integer
function Animation:_require_interval(what)
  local interval = self._interval
  if interval == nil then
    error("nui.animation: `interval` is required " .. what)
  end
  return interval
end

---@private
---Map eased progress in [0, 1] to a frame index (0-based), clamping overshoot
---easings (for example `out_back`) back into range.
---@param t number
---@return integer
function Animation:_list_index(t)
  local n = self._frame_count
  return math.max(0, math.min(math.floor(t * n), n - 1))
end

---Progress loops (every `duration` for a function, every `interval * #frames`
---for a list), so callers can pass an ever-increasing elapsed time.
---@param elapsed integer milliseconds since the animation began
---@return NuiAnimation
function Animation:seek(elapsed)
  self._elapsed = elapsed
  self._completed = false

  if self._generate then
    if self._cycle and elapsed >= self._cycle * self._duration then
      self._completed = true
      self._frame = self._generate(self._easing(1))
    else
      local t = (elapsed % self._duration) / self._duration
      self._frame = self._generate(self._easing(t))
    end
  else
    local interval = self:_require_interval("to `seek` a list frame")
    local n = self._frame_count
    local index
    if self._cycle and math.floor(elapsed / interval) >= self._cycle * n - 1 then
      -- finished the last cycle: hold the final frame
      self._completed = true
      index = n - 1
    elseif self._easing then
      local cycle_len = interval * n
      index = self:_list_index(self._easing((elapsed % cycle_len) / cycle_len))
    else
      index = math.floor(elapsed / interval) % n
    end
    self._frame = self._frames[index + 1]
  end

  return self
end

---Advance one step (`interval` ms) — deterministic regardless of wall-clock
---time. Requires `interval`.
---@return NuiAnimation
function Animation:next()
  local interval = self:_require_interval("for `next`")
  return self:seek(self._elapsed + interval)
end

---Return to the start; requires no `interval`.
---@return NuiAnimation
function Animation:reset()
  self._elapsed = 0
  self._completed = false
  if self._generate then
    self._frame = self._generate(self._easing(0))
  elseif self._easing then
    self._frame = self._frames[self:_list_index(self._easing(0)) + 1]
  else
    self._frame = self._frames[1]
  end
  return self
end

---@private
function Animation:_close_timer()
  if self._timer then
    self._timer:stop()
    if not self._timer:is_closing() then
      self._timer:close()
    end
    self._timer = nil
  end
end

---@class nui_animation_start_options
---@field on_stop? fun(animation: NuiAnimation): nil called once when the running timer stops

---Run a timer that advances the animation every `interval` ms and calls
---`on_tick` on the main loop after each advance. To drive advancement yourself
---(without a timer), use `next`/`seek` instead. Calling `start` again restarts.
---Requires `interval`.
---
---A list advances one frame per tick (deterministic); a function is advanced by
---the real elapsed time each tick, so it stays accurate under jitter (set
---`interval` to your frame period, e.g. 16 for ~60fps). `reset`/`seek` take
---effect even while running.
---
---With a `cycle` count, the timer stops itself after the last frame of the last
---cycle. `opts.on_stop` (if given) fires once when the running timer stops,
---whether from finishing its cycles or from a `stop()` call. It does not fire on
---restart.
---@param on_tick fun(animation: NuiAnimation): nil
---@param opts? nui_animation_start_options
---@return NuiAnimation
function Animation:start(on_tick, opts)
  local interval = self:_require_interval("for `start`")
  if type(on_tick) ~= "function" then
    error("nui.animation: `on_tick` must be a function")
  end
  if opts ~= nil and type(opts) ~= "table" then
    error("nui.animation: `opts` must be a table")
  end
  opts = opts or {}
  local on_stop = opts.on_stop
  if on_stop ~= nil and type(on_stop) ~= "function" then
    error("nui.animation: `on_stop` must be a function")
  end
  self:_close_timer() -- restart is silent: the previous `on_stop` never fires
  self._on_stop = on_stop

  local timer = assert(uv.new_timer())
  self._timer = timer
  local last_tick = uv.now()
  timer:start(
    interval,
    interval,
    vim.schedule_wrap(function()
      -- guard: stale tick from a replaced or stopped timer (race, not
      -- deterministically reachable)
      -- luacov: disable
      if self._timer ~= timer then
        return
      end
      -- luacov: enable
      if self._generate then
        local now = uv.now()
        self:seek(self._elapsed + (now - last_tick))
        last_tick = now
      else
        self:next()
      end
      on_tick(self)
      if self._completed then
        self:stop()
      end
    end)
  )

  return self
end

---Stop the timer. Idempotent; safe when not started. Fires `on_stop` once if a
---running timer is stopped.
---@return NuiAnimation
function Animation:stop()
  if self._timer then
    self:_close_timer()
    local on_stop = self._on_stop
    self._on_stop = nil
    if on_stop then
      on_stop(self)
    end
  end

  return self
end

---@alias NuiAnimation.constructor fun(options: nui_animation_options): NuiAnimation
---@type NuiAnimation|NuiAnimation.constructor
local NuiAnimation = Animation

return NuiAnimation
