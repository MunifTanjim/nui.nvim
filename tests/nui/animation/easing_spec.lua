pcall(require, "luacov")

local easings = require("nui.animation.easing")

local h = require("tests.helpers")

local eq = h.eq
local approx = h.approx

describe("nui.animation.easing", function()
  local samples = { 0, 0.25, 0.5, 0.75, 1 }

  ---@param name string
  ---@param expected number[]
  local function assert_easing(name, expected)
    local fn = easings[name]
    for i = 1, #samples do
      eq(fn(samples[i]), expected[i])
    end
  end

  it("linear", function()
    assert_easing("linear", { 0, 0.25, 0.5, 0.75, 1 })
  end)

  it("in_quad", function()
    assert_easing("in_quad", { 0, 0.0625, 0.25, 0.5625, 1 })
  end)

  it("out_quad", function()
    assert_easing("out_quad", { 0, 0.4375, 0.75, 0.9375, 1 })
  end)

  it("in_out_quad", function()
    assert_easing("in_out_quad", { 0, 0.125, 0.5, 0.875, 1 })
  end)

  it("in_cubic", function()
    assert_easing("in_cubic", { 0, 0.015625, 0.125, 0.421875, 1 })
  end)

  it("out_cubic", function()
    assert_easing("out_cubic", { 0, 0.578125, 0.875, 0.984375, 1 })
  end)

  it("in_out_cubic", function()
    assert_easing("in_out_cubic", { 0, 0.0625, 0.5, 0.9375, 1 })
  end)

  it("in_quart", function()
    assert_easing("in_quart", { 0, 0.00390625, 0.0625, 0.31640625, 1 })
  end)

  it("out_quart", function()
    assert_easing("out_quart", { 0, 0.68359375, 0.9375, 0.99609375, 1 })
  end)

  it("in_out_quart", function()
    assert_easing("in_out_quart", { 0, 0.03125, 0.5, 0.96875, 1 })
  end)

  it("in_quint", function()
    assert_easing("in_quint", { 0, 0.0009765625, 0.03125, 0.2373046875, 1 })
  end)

  it("out_quint", function()
    assert_easing("out_quint", { 0, 0.7626953125, 0.96875, 0.9990234375, 1 })
  end)

  it("in_out_quint", function()
    assert_easing("in_out_quint", { 0, 0.015625, 0.5, 0.984375, 1 })
  end)

  it("every preset starts at 0 and ends at 1", function()
    local count = 0
    for name, fn in pairs(easings) do
      if name ~= "cubic_bezier" then -- a factory, not an easing
        count = count + 1
        approx(fn(0), 0, 1e-9)
        approx(fn(1), 1, 1e-9)
      end
    end
    -- linear + in/out/in_out for 10 families
    eq(count, 31)
  end)

  describe("in / out / in_out relationships", function()
    local families = { "sine", "quad", "cubic", "quart", "quint", "expo", "circ", "back", "elastic", "bounce" }
    local ts = { 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9 }

    it("out(t) == 1 - in(1 - t) for every family", function()
      for _, fam in ipairs(families) do
        local ease_in = easings["in_" .. fam]
        local ease_out = easings["out_" .. fam]
        for _, t in ipairs(ts) do
          approx(ease_out(t), 1 - ease_in(1 - t), 1e-9)
        end
      end
    end)

    it("in_out(t) == 1 - in_out(1 - t) for every family", function()
      for _, fam in ipairs(families) do
        local ease = easings["in_out_" .. fam]
        for _, t in ipairs(ts) do
          approx(ease(t), 1 - ease(1 - t), 1e-9)
        end
      end
    end)
  end)

  describe("monotonicity", function()
    -- families that never overshoot: output must be non-decreasing on [0, 1]
    local names = {
      "linear",
      "in_sine",
      "out_sine",
      "in_out_sine",
      "in_quad",
      "out_quad",
      "in_out_quad",
      "in_cubic",
      "out_cubic",
      "in_out_cubic",
      "in_quart",
      "out_quart",
      "in_out_quart",
      "in_quint",
      "out_quint",
      "in_out_quint",
      "in_expo",
      "out_expo",
      "in_out_expo",
      "in_circ",
      "out_circ",
      "in_out_circ",
    }

    it("non-overshoot easings are non-decreasing", function()
      for _, name in ipairs(names) do
        local fn = easings[name]
        local prev = fn(0)
        for i = 1, 100 do
          local y = fn(i / 100)
          eq(y >= prev - 1e-9, true)
          prev = y
        end
      end
    end)
  end)

  describe("cubic_bezier", function()
    it("returns an easing function", function()
      eq(type(easings.cubic_bezier(0.25, 0.1, 0.25, 1)), "function")
    end)

    it("maps the endpoints and reduces to linear on the diagonal", function()
      local fn = easings.cubic_bezier(0, 0, 1, 1)
      approx(fn(0), 0, 1e-6)
      approx(fn(0.25), 0.25, 1e-6)
      approx(fn(0.5), 0.5, 1e-6)
      approx(fn(0.75), 0.75, 1e-6)
      approx(fn(1), 1, 1e-6)
    end)

    it("errors when x1 or x2 is outside [0, 1]", function()
      h.errors(function()
        easings.cubic_bezier(1.5, 0, 0.5, 1)
      end, "`x1` and `x2` must be in [0, 1]", true)
    end)

    it("solves a flat-start bezier via the bisection fallback", function()
      -- x1 = x2 = 0 gives x(u) = u^3, so Newton's derivative vanishes near 0 and
      -- bisection takes over; y(u) = 3u^2 - 2u^3, with u^3 = x
      local fn = easings.cubic_bezier(0, 0, 0, 1)
      approx(fn(0.1), 3 * 0.1 ^ (2 / 3) - 2 * 0.1, 1e-4)
      approx(fn(0.01), 3 * 0.01 ^ (2 / 3) - 2 * 0.01, 1e-4)
      approx(fn(0), 0, 1e-9)
      approx(fn(1), 1, 1e-9)
    end)
  end)
end)
