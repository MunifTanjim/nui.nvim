-- Easing functions adapted from https://easings.net. `t` is progress in [0, 1].

local sin, cos, sqrt, pi = math.sin, math.cos, math.sqrt, math.pi

local c1 = 1.70158
local c2 = c1 * 1.525
local c3 = c1 + 1
local c4 = (2 * pi) / 3
local c5 = (2 * pi) / 4.5

---@param t number
---@return number
local function out_bounce(t)
  local n1, d1 = 7.5625, 2.75
  if t < 1 / d1 then
    return n1 * t * t
  elseif t < 2 / d1 then
    t = t - 1.5 / d1
    return n1 * t * t + 0.75
  elseif t < 2.5 / d1 then
    t = t - 2.25 / d1
    return n1 * t * t + 0.9375
  else
    t = t - 2.625 / d1
    return n1 * t * t + 0.984375
  end
end

---@class nui_animation_easings
---@field [string] fun(t: number): number
---@field cubic_bezier fun(x1: number, y1: number, x2: number, y2: number): (fun(t: number): number)
local easings = {
  linear = function(t)
    return t
  end,

  in_sine = function(t)
    return 1 - cos((t * pi) / 2)
  end,
  out_sine = function(t)
    return sin((t * pi) / 2)
  end,
  in_out_sine = function(t)
    return -(cos(pi * t) - 1) / 2
  end,

  in_quad = function(t)
    return t * t
  end,
  out_quad = function(t)
    return 1 - (1 - t) ^ 2
  end,
  in_out_quad = function(t)
    if t < 0.5 then
      return 2 * t * t
    end
    return 1 - (-2 * t + 2) ^ 2 / 2
  end,

  in_cubic = function(t)
    return t ^ 3
  end,
  out_cubic = function(t)
    return 1 - (1 - t) ^ 3
  end,
  in_out_cubic = function(t)
    if t < 0.5 then
      return 4 * t ^ 3
    end
    return 1 - (-2 * t + 2) ^ 3 / 2
  end,

  in_quart = function(t)
    return t ^ 4
  end,
  out_quart = function(t)
    return 1 - (1 - t) ^ 4
  end,
  in_out_quart = function(t)
    if t < 0.5 then
      return 8 * t ^ 4
    end
    return 1 - (-2 * t + 2) ^ 4 / 2
  end,

  in_quint = function(t)
    return t ^ 5
  end,
  out_quint = function(t)
    return 1 - (1 - t) ^ 5
  end,
  in_out_quint = function(t)
    if t < 0.5 then
      return 16 * t ^ 5
    end
    return 1 - (-2 * t + 2) ^ 5 / 2
  end,

  in_expo = function(t)
    if t == 0 then
      return 0
    end
    return 2 ^ (10 * t - 10)
  end,
  out_expo = function(t)
    if t == 1 then
      return 1
    end
    return 1 - 2 ^ (-10 * t)
  end,
  in_out_expo = function(t)
    if t == 0 then
      return 0
    end
    if t == 1 then
      return 1
    end
    if t < 0.5 then
      return 2 ^ (20 * t - 10) / 2
    end
    return (2 - 2 ^ (-20 * t + 10)) / 2
  end,

  in_circ = function(t)
    return 1 - sqrt(1 - t ^ 2)
  end,
  out_circ = function(t)
    return sqrt(1 - (t - 1) ^ 2)
  end,
  in_out_circ = function(t)
    if t < 0.5 then
      return (1 - sqrt(1 - (2 * t) ^ 2)) / 2
    end
    return (sqrt(1 - (-2 * t + 2) ^ 2) + 1) / 2
  end,

  in_back = function(t)
    return c3 * t ^ 3 - c1 * t ^ 2
  end,
  out_back = function(t)
    return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
  end,
  in_out_back = function(t)
    if t < 0.5 then
      return ((2 * t) ^ 2 * ((c2 + 1) * 2 * t - c2)) / 2
    end
    return ((2 * t - 2) ^ 2 * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
  end,

  in_elastic = function(t)
    if t == 0 then
      return 0
    end
    if t == 1 then
      return 1
    end
    return -(2 ^ (10 * t - 10)) * sin((t * 10 - 10.75) * c4)
  end,
  out_elastic = function(t)
    if t == 0 then
      return 0
    end
    if t == 1 then
      return 1
    end
    return 2 ^ (-10 * t) * sin((t * 10 - 0.75) * c4) + 1
  end,
  in_out_elastic = function(t)
    if t == 0 then
      return 0
    end
    if t == 1 then
      return 1
    end
    if t < 0.5 then
      return -(2 ^ (20 * t - 10) * sin((20 * t - 11.125) * c5)) / 2
    end
    return (2 ^ (-20 * t + 10) * sin((20 * t - 11.125) * c5)) / 2 + 1
  end,

  in_bounce = function(t)
    return 1 - out_bounce(1 - t)
  end,
  out_bounce = out_bounce,
  in_out_bounce = function(t)
    if t < 0.5 then
      return (1 - out_bounce(1 - 2 * t)) / 2
    end
    return (1 + out_bounce(2 * t - 1)) / 2
  end,
}

---Build an easing function from a cubic Bézier, like CSS `cubic-bezier()`.
---The control points are (x1, y1) and (x2, y2); the endpoints are fixed at
---(0, 0) and (1, 1). x1 and x2 must be in [0, 1] so the curve stays a function
---of time.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return fun(t: number): number
local function cubic_bezier(x1, y1, x2, y2)
  if x1 < 0 or x1 > 1 or x2 < 0 or x2 > 1 then
    error("nui.animation: cubic_bezier `x1` and `x2` must be in [0, 1]")
  end

  -- polynomial coefficients of the Bézier (WebKit UnitBezier form)
  local cx = 3 * x1
  local bx = 3 * (x2 - x1) - cx
  local ax = 1 - cx - bx
  local cy = 3 * y1
  local by = 3 * (y2 - y1) - cy
  local ay = 1 - cy - by

  local function sample_x(u)
    return ((ax * u + bx) * u + cx) * u
  end
  local function sample_y(u)
    return ((ay * u + by) * u + cy) * u
  end
  local function sample_dx(u)
    return (3 * ax * u + 2 * bx) * u + cx
  end

  -- invert x (time) to the curve parameter u
  local function solve(x)
    local u = x
    for _ = 1, 8 do -- Newton-Raphson
      local err = sample_x(u) - x
      if math.abs(err) < 1e-7 then
        return u
      end
      local dx = sample_dx(u)
      if math.abs(dx) < 1e-7 then
        break
      end
      u = u - err / dx
    end

    -- bisection fallback: Newton stalls where the derivative is ~0 (e.g. a
    -- flat-start Bézier, x1 = x2 = 0)
    local lo, hi = 0, 1
    u = x
    for _ = 1, 40 do
      local err = sample_x(u) - x
      if math.abs(err) < 1e-7 then
        return u
      end
      if err > 0 then
        hi = u
      else
        lo = u
      end
      u = (lo + hi) / 2
    end

    -- unreachable: bisection always converges within 40 iterations
    -- luacov: disable
    return u
    -- luacov: enable
  end

  return function(t)
    if t <= 0 then
      return 0
    end
    if t >= 1 then
      return 1
    end
    return sample_y(solve(t))
  end
end

easings.cubic_bezier = cubic_bezier

return easings
