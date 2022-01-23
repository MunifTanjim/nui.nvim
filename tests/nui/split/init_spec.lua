pcall(require, "luacov")

local Split = require("nui.split")
local h = require("tests.nui")
local spy = require("luassert.spy")

local feedkeys = h.feedkeys

describe("nui.split", function()
  local split

  after_each(function()
    split:unmount()
  end)

  describe("method :map", function()
    it("supports lhs table", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", { "k", "l" }, "o42<esc>")

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
        "42",
        "42",
      })
    end)

    it("supports rhs function", function()
      local callback = spy.new(function() end)

      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "l", function()
        callback()
      end)

      feedkeys("l", "x")

      assert.spy(callback).called()
    end)

    it("supports rhs string", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "l", "o42<esc>")

      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
        "42",
      })
    end)

    it("supports o.remap=true", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "k", "o42<Esc>")
      split:map("n", "l", "k", { remap = true })

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
        "42",
        "42",
      })
    end)

    it("supports o.remap=false", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "k", "o42<Esc>")
      split:map("n", "l", "k", { remap = false })

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
        "42",
      })
    end)
  end)

  describe("method :unmap", function()
    it("supports lhs string", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "l", "o42<esc>")

      split:unmap("n", "l")

      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
      })
    end)

    it("supports lhs table", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "k", "o42<esc>")
      split:map("n", "l", "o42<esc>")

      split:unmap("n", { "k", "l" })

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
      })
    end)
  end)
end)
