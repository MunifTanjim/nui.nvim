pcall(require, "luacov")

local Animation = require("nui.animation")

local h = require("tests.helpers")

local eq = h.eq
local approx = h.approx

describe("nui.animation", function()
  describe("(construction)", function()
    it("errors when frame is missing", function()
      h.errors(function()
        Animation({})
      end, "`frame` must be a non-empty array or a function", true)
    end)

    it("errors when frame is neither a list nor a function", function()
      h.errors(function()
        Animation({ frame = "nope" })
      end, "`frame` must be a non-empty array or a function", true)
    end)

    it("errors when frame is an empty array", function()
      h.errors(function()
        Animation({ frame = {} })
      end, "`frame` must be a non-empty array or a function", true)
    end)

    it("errors when interval is not positive", function()
      h.errors(function()
        Animation({ frame = { "a" }, interval = 0 })
      end, "`interval` must be a positive number", true)
    end)

    it("errors when duration is missing or not positive", function()
      h.errors(function()
        Animation({
          frame = function(t)
            return t
          end,
        })
      end, "`duration` must be a positive number", true)

      h.errors(function()
        Animation({
          frame = function(t)
            return t
          end,
          duration = 0,
        })
      end, "`duration` must be a positive number", true)
    end)

    it("errors on an unknown easing preset", function()
      h.errors(function()
        Animation({
          frame = function(t)
            return t
          end,
          duration = 100,
          easing = "no-such-easing",
        })
      end, "unknown easing 'no-such-easing'", true)
    end)

    it("errors when easing is neither a preset name nor a function", function()
      h.errors(function()
        Animation({
          frame = function(t)
            return t
          end,
          duration = 100,
          easing = 42,
        })
      end, "`easing` must be a preset name or a function", true)
    end)
  end)

  describe("(list frame)", function()
    it("exposes the first frame via :frame()", function()
      local animation = Animation({ frame = { "a", "b" } })

      eq(animation:frame(), "a")
    end)

    it(":next() advances to the following frame and returns self", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 80 })

      eq(animation:next(), animation)
      eq(animation:frame(), "b")
    end)

    it(":next() wraps around after the last frame", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 80 })

      animation:next():next()
      eq(animation:frame(), "a")
    end)

    it(":seek() maps elapsed time to a frame by interval and returns self", function()
      local animation = Animation({ frame = { "a", "b", "c" }, interval = 100 })

      eq(animation:seek(100), animation)
      eq(animation:frame(), "b")
      animation:seek(200)
      eq(animation:frame(), "c")
      animation:seek(300)
      eq(animation:frame(), "a")
    end)

    it("applies easing to a list frame", function()
      local animation = Animation({
        frame = { "a", "b", "c", "d" },
        interval = 100,
        easing = function(_)
          return 0.5
        end,
      })

      -- constant easing 0.5 -> floor(0.5 * 4) = 2 -> frame[3] = "c", always
      eq(animation:frame(), "c")
      animation:seek(250)
      eq(animation:frame(), "c")
    end)

    it("clamps an overshooting easing to a valid list frame", function()
      local frames = { "a", "b", "c", "d" }
      local animation = Animation({ frame = frames, interval = 100, easing = "out_back" })

      -- out_back overshoots past 1; the index must stay within the list
      for e = 0, 100 * #frames do
        animation:seek(e)
        eq(vim.tbl_contains(frames, animation:frame()), true)
      end
    end)

    it(":reset() returns to the first frame and returns self", function()
      local animation = Animation({ frame = { "a", "b", "c" }, interval = 80 })

      animation:next():next()
      eq(animation:frame(), "c")
      eq(animation:reset(), animation)
      eq(animation:frame(), "a")
    end)

    it("requires `interval` for :next() and :seek()", function()
      local animation = Animation({ frame = { "a", "b" } })

      -- no interval: construction and :frame()/:reset() still work
      eq(animation:frame(), "a")
      eq(animation:reset(), animation)

      h.errors(function()
        animation:next()
      end, "`interval` is required for `next`", true)

      h.errors(function()
        animation:seek(100)
      end, "`interval` is required to `seek` a list frame", true)
    end)
  end)

  describe("(function frame)", function()
    it("shapes the initial frame with the easing", function()
      local received = nil
      local animation = Animation({
        frame = function(t)
          received = t
          return t
        end,
        duration = 1000,
        easing = function(_)
          return 0.5
        end,
      })

      eq(received, 0.5)
      eq(animation:frame(), 0.5)
    end)

    it(":seek() maps elapsed time to progress and returns self", function()
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
      })

      eq(animation:seek(250), animation)
      eq(animation:frame(), 0.25)
      animation:seek(500)
      eq(animation:frame(), 0.5)
    end)

    it("seeks without an interval, but requires it for :next()/:start()", function()
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
      })

      -- a seek-driven function needs no interval
      animation:seek(500)
      eq(animation:frame(), 0.5)

      h.errors(function()
        animation:next()
      end, "`interval` is required for `next`", true)

      h.errors(function()
        animation:start()
      end, "`interval` is required for `start`", true)
    end)

    it(":seek() shapes progress through the easing", function()
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
        easing = function(t)
          return t * 0.5
        end,
      })

      -- raw progress at 500ms is 0.5; the easing halves it to 0.25
      animation:seek(500)
      eq(animation:frame(), 0.25)
    end)

    it(":seek() loops progress every duration", function()
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
      })

      animation:seek(1000)
      eq(animation:frame(), 0)
      animation:seek(1250)
      eq(animation:frame(), 0.25)
    end)

    it(":next() advances progress by one interval", function()
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
        interval = 100,
      })

      eq(animation:next(), animation)
      eq(animation:frame(), 0.1)
      animation:next()
      eq(animation:frame(), 0.2)
    end)

    it(":reset() returns to the start of the timeline", function()
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
        interval = 100,
        easing = function(t)
          return t * 0.5
        end,
      })

      animation:next()
      eq(animation:frame(), 0.05)
      eq(animation:reset(), animation)
      eq(animation:frame(), 0)
    end)

    it("accepts a cubic_bezier easing", function()
      local easing = require("nui.animation.easing")
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
        easing = easing.cubic_bezier(0, 0, 1, 1), -- reduces to linear
      })

      animation:seek(500)
      approx(animation:frame(), 0.5, 1e-6)
    end)
  end)

  describe("(finite)", function()
    it("errors when cycle is not a positive integer", function()
      h.errors(function()
        Animation({ frame = { "a" }, cycle = 0 })
      end, "`cycle` must be a positive integer", true)

      h.errors(function()
        Animation({ frame = { "a" }, cycle = 1.5 })
      end, "`cycle` must be a positive integer", true)
    end)

    it("clamps a list to the last frame after `cycle` cycles", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 100, cycle = 2 })

      -- cycle 1: a(0) b(100); cycle 2: a(200) b(300, last)
      eq(animation:frame(), "a")
      animation:seek(100)
      eq(animation:frame(), "b")
      animation:seek(200)
      eq(animation:frame(), "a")
      animation:seek(300)
      eq(animation:frame(), "b")

      -- past the end holds the final frame
      animation:seek(400)
      eq(animation:frame(), "b")
      animation:seek(99999)
      eq(animation:frame(), "b")
    end)

    it(":next() stops advancing at the last frame of the last cycle", function()
      local animation = Animation({ frame = { "a", "b", "c" }, interval = 10, cycle = 1 })

      animation:next()
      eq(animation:frame(), "b")
      animation:next()
      eq(animation:frame(), "c")
      animation:next()
      eq(animation:frame(), "c")
    end)

    it("clamps a function timeline at t=1 after `cycle` cycles", function()
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
        cycle = 2,
      })

      animation:seek(500)
      eq(animation:frame(), 0.5)
      animation:seek(1500) -- cycle 2 midway
      eq(animation:frame(), 0.5)
      animation:seek(2000) -- complete, clamp to t=1
      eq(animation:frame(), 1)
      animation:seek(2500)
      eq(animation:frame(), 1)
    end)

    it(":reset() replays a completed animation", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 100, cycle = 1 })

      animation:seek(1000) -- past the end
      eq(animation:frame(), "b")
      animation:reset()
      eq(animation:frame(), "a")
      animation:seek(100)
      eq(animation:frame(), "b")
    end)

    it(":start() auto-stops a finite animation and fires on_stop with the last frame", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 10, cycle = 1 })

      local frames = {}
      local stopped = false
      animation:start(function(a)
        table.insert(frames, a:frame())
      end, {
        on_stop = function()
          stopped = true
        end,
      })

      vim.wait(500, function()
        return stopped
      end)

      eq(stopped, true)
      eq(frames[#frames], "b")
    end)
  end)

  describe(":start() / :stop()", function()
    it(":start() advances a list frame per tick, invokes on_tick, returns self", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 10 })

      local ticks = {}
      eq(
        animation:start(function(a)
          table.insert(ticks, a:frame())
        end),
        animation
      )

      vim.wait(500, function()
        return #ticks >= 2
      end)
      animation:stop()

      eq(ticks[1], "b")
      eq(ticks[2], "a")
    end)

    it(":start() re-samples a function frame from elapsed time", function()
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
        interval = 10,
      })

      local seen = {}
      animation:start(function(a)
        table.insert(seen, a:frame())
      end)

      vim.wait(500, function()
        return #seen >= 3
      end)
      animation:stop()

      eq(#seen >= 3, true)
      eq(seen[1] < seen[2], true)
      for _, v in ipairs(seen) do
        eq(v >= 0 and v < 1, true)
      end
    end)

    it(":reset() restarts a running function animation", function()
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
        interval = 10,
      })

      animation:start(function() end)
      vim.wait(500, function()
        return animation:frame() > 0.3
      end)

      animation:reset()
      vim.wait(50) -- let ticks fire after the reset
      local after = animation:frame()
      animation:stop()

      -- the reset persists across ticks; progress climbs again from ~0
      eq(after < 0.2, true)
    end)

    it(":seek() persists on a running function animation", function()
      local animation = Animation({
        frame = function(t)
          return t
        end,
        duration = 1000,
        interval = 10,
      })

      animation:start(function() end)
      vim.wait(500, function()
        return animation:frame() > 0.3
      end)

      animation:seek(0)
      vim.wait(50)
      local after = animation:frame()
      animation:stop()

      eq(after < 0.2, true)
    end)

    it(":start() requires an `on_tick` function", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 10 })

      h.errors(function()
        animation:start()
      end, "`on_tick` must be a function", true)
    end)

    it(":start() errors when opts is not a table", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 10 })

      h.errors(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        animation:start(function() end, 42)
      end, "`opts` must be a table", true)
    end)

    it(":start() errors when opts.on_stop is not a function", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 10 })

      h.errors(function()
        ---@diagnostic disable-next-line: assign-type-mismatch
        animation:start(function() end, { on_stop = 42 })
      end, "`on_stop` must be a function", true)
    end)

    it(":stop() fires on_stop once when stopping a running animation", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 10 })

      local stopped = 0
      animation:start(function() end, {
        on_stop = function()
          stopped = stopped + 1
        end,
      })

      animation:stop()
      animation:stop() -- no-op, must not fire again

      eq(stopped, 1)
    end)

    it(":start() restarting does not fire the previous on_stop", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 10 })

      local stopped = 0
      animation:start(function() end, {
        on_stop = function()
          stopped = stopped + 1
        end,
      })
      animation:start(function() end) -- restart: previous on_stop must not fire

      eq(stopped, 0)
      animation:stop()
      eq(stopped, 0)
    end)

    it(":stop() halts further ticks", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 10 })

      local count = 0
      animation:start(function()
        count = count + 1
      end)

      vim.wait(500, function()
        return count >= 1
      end)
      animation:stop()

      local count_at_stop = count
      vim.wait(100)

      eq(count, count_at_stop)
    end)

    it(":stop() is safe to call when not started", function()
      local animation = Animation({ frame = { "a" } })

      eq(animation:stop(), animation)
    end)

    it("can restart after :stop()", function()
      local animation = Animation({ frame = { "a", "b" }, interval = 10 })

      local count = 0
      animation:start(function()
        count = count + 1
      end)
      vim.wait(500, function()
        return count >= 1
      end)
      animation:stop()

      count = 0
      animation:start(function()
        count = count + 1
      end)
      vim.wait(500, function()
        return count >= 1
      end)
      animation:stop()

      eq(count >= 1, true)
    end)
  end)
end)
