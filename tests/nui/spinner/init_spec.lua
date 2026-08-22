pcall(require, "luacov")

local Spinner = require("nui.spinner")
local NuiLine = require("nui.line")
local h = require("tests.helpers")

local eq = h.eq

describe("nui.spinner", function()
  it("renders the first frame of the default preset via :text()", function()
    local spinner = Spinner()

    eq(spinner:text():content(), "⠋")
  end)

  it("constructs and renders with every built-in preset", function()
    local presets = require("nui.spinner.preset")

    local count = 0
    for name in pairs(presets) do
      count = count + 1
      local spinner = Spinner({ animation = name })
      eq(type(spinner:text():content()), "string")
    end
    eq(count, 90)
  end)

  it("resolves a named preset other than the default", function()
    local spinner = Spinner({ animation = "line" })

    eq(spinner:text():content(), "-")
  end)

  ---@param spinner NuiSpinner
  local function interval_of(spinner)
    ---@diagnostic disable-next-line: invisible
    return spinner._animation._interval
  end

  it("uses the preset's own interval when none is given", function()
    eq(interval_of(Spinner({ animation = "clock" })), 100)
    eq(interval_of(Spinner({ animation = "dots" })), 80)
  end)

  it("uses the interval from a custom animation table", function()
    eq(interval_of(Spinner({ animation = { frame = { "a", "b" }, interval = 25 } })), 25)
  end)

  it("errors on a custom animation without an interval", function()
    h.errors(function()
      Spinner({ animation = { frame = { "a", "b" } } })
    end, "needs a positive `interval`", true)
  end)

  it("errors on an unknown preset name", function()
    h.errors(function()
      Spinner({ animation = "no-such-preset" })
    end, "unknown preset 'no-such-preset'", true)
  end)

  it("errors on an empty custom frames list", function()
    h.errors(function()
      Spinner({ animation = { frame = {} } })
    end, "needs a non-empty `frame` list", true)
  end)

  it("errors when animation is neither a name nor a table", function()
    h.errors(function()
      ---@diagnostic disable-next-line: assign-type-mismatch
      Spinner({ animation = 42 })
    end, "must be a preset name or a table", true)
  end)

  it("errors on an invalid cycle count", function()
    h.errors(function()
      Spinner({ animation = { frame = { "a" }, interval = 10 }, cycle = 0 })
    end, "`cycle` must be a positive integer", true)
  end)

  it(":next() advances to the following frame and returns self", function()
    local spinner = Spinner()

    eq(spinner:next(), spinner)
    eq(spinner:text():content(), "⠙")
  end)

  it(":next() wraps around after the last frame", function()
    local spinner = Spinner({ animation = { frame = { "a", "b" }, interval = 80 } })

    spinner:next()
    eq(spinner:text():content(), "b")
    spinner:next()
    eq(spinner:text():content(), "a")
  end)

  it(":reset() returns to the first frame and returns self", function()
    local spinner = Spinner({ animation = { frame = { "a", "b", "c" }, interval = 80 } })

    spinner:next():next()
    eq(spinner:text():content(), "c")
    eq(spinner:reset(), spinner)
    eq(spinner:text():content(), "a")
  end)

  it("renders just the glyph via :text()", function()
    local spinner = Spinner({ animation = { frame = { "x" }, interval = 80 } })

    eq(spinner:text():content(), "x")
  end)

  it("highlights the glyph with the configured hl group", function()
    local spinner = Spinner({ animation = { frame = { "x" }, interval = 80 }, hl = "NuiSpinnerTest" })

    local bufnr = vim.api.nvim_create_buf(false, true)
    local ns_id = vim.api.nvim_create_namespace("NuiSpinnerTest")
    local line = NuiLine()
    line:append(spinner:text())
    line:render(bufnr, ns_id, 1)

    h.assert_highlight(bufnr, ns_id, 1, "x", "NuiSpinnerTest")
  end)

  describe(":start() / :stop()", function()
    it(":start() ticks the frame and invokes the callback, returns self", function()
      local spinner = Spinner({ animation = { frame = { "a", "b" }, interval = 10 } })

      local ticks = {}
      eq(
        spinner:start(function(s)
          table.insert(ticks, s:text():content())
        end),
        spinner
      )

      vim.wait(500, function()
        return #ticks >= 2
      end)
      spinner:stop()

      eq(ticks[1], "b")
      eq(ticks[2], "a")
    end)

    it(":start() requires an `on_tick` function", function()
      local spinner = Spinner()

      h.errors(function()
        spinner:start()
      end, "`on_tick` must be a function", true)
    end)

    it(":start() errors when opts is not a table", function()
      local spinner = Spinner()

      h.errors(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        spinner:start(function() end, 42)
      end, "`opts` must be a table", true)
    end)

    it(":start() errors when opts.on_stop is not a function", function()
      local spinner = Spinner()

      h.errors(function()
        ---@diagnostic disable-next-line: assign-type-mismatch
        spinner:start(function() end, { on_stop = 42 })
      end, "`on_stop` must be a function", true)
    end)

    it("plays a finite spinner and fires on_stop with the spinner", function()
      local spinner = Spinner({ animation = { frame = { "a", "b" }, interval = 10 }, cycle = 1 })

      local got
      spinner:start(function() end, {
        on_stop = function(s)
          got = s
        end,
      })

      vim.wait(500, function()
        return got ~= nil
      end)

      eq(got, spinner)
    end)

    it(":stop() halts further ticks", function()
      local spinner = Spinner({ animation = { frame = { "a", "b" }, interval = 10 } })

      local count = 0
      spinner:start(function()
        count = count + 1
      end)

      vim.wait(500, function()
        return count >= 1
      end)
      spinner:stop()

      local count_at_stop = count
      vim.wait(100)

      eq(count, count_at_stop)
    end)

    it(":stop() is safe to call when not started", function()
      local spinner = Spinner()

      eq(spinner:stop(), spinner)
    end)

    it("can restart after :stop()", function()
      local spinner = Spinner({ animation = { frame = { "a", "b" }, interval = 10 } })

      local count = 0
      spinner:start(function()
        count = count + 1
      end)
      vim.wait(500, function()
        return count >= 1
      end)
      spinner:stop()

      count = 0
      spinner:start(function()
        count = count + 1
      end)
      vim.wait(500, function()
        return count >= 1
      end)
      spinner:stop()

      eq(count >= 1, true)
    end)
  end)
end)
