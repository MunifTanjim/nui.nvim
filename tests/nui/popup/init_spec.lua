pcall(require, "luacov")

local Popup = require("nui.popup")
local h = require("tests.nui")
local spy = require("luassert.spy")

local eq, feedkeys = h.eq, h.feedkeys

describe("nui.popup", function()
  local popup

  after_each(function()
    popup:unmount()
  end)

  it("supports o.bufnr (unmanaed buffer)", function()
    local bufnr = vim.api.nvim_create_buf(false, true)

    local lines = {
      "a",
      "b",
      "c",
    }

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    popup = Popup({
      bufnr = bufnr,
      position = "50%",
      size = {
        height = "60%",
        width = "80%",
      },
    })

    h.assert_buf_lines(bufnr, lines)
    eq(popup.bufnr, bufnr)
    popup:mount()
    h.assert_buf_lines(bufnr, lines)
    popup:unmount()
    eq(popup.bufnr, bufnr)
    h.assert_buf_lines(bufnr, lines)
  end)

  it("accepts number as o.ns_id", function()
    local ns = "NuiPopupTest"
    local ns_id = vim.api.nvim_create_namespace(ns)

    popup = Popup({
      ns_id = ns_id,
      position = "50%",
      size = {
        height = "60%",
        width = "80%",
      },
    })

    eq(popup.ns_id, ns_id)
  end)

  it("accepts string as o.ns_id", function()
    local ns = "NuiPopupTest"

    popup = Popup({
      ns_id = ns,
      position = "50%",
      size = {
        height = "60%",
        width = "80%",
      },
    })

    eq(popup.ns_id, vim.api.nvim_create_namespace(ns))
  end)

  it("uses fallback ns_id if o.ns_id=nil", function()
    popup = Popup({
      position = "50%",
      size = {
        height = "60%",
        width = "80%",
      },
    })

    eq(type(popup.ns_id), "number")
    eq(popup.ns_id > 0, true)
  end)

  h.describe_flipping_feature("lua_keymap", "method :map", function()
    it("supports lhs table", function()
      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", { "k", "l" }, "o42<esc>")

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(popup.bufnr, {
        "",
        "42",
        "42",
      })
    end)

    it("supports rhs function", function()
      local callback = spy.new(function() end)

      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "l", function()
        callback()
      end)

      feedkeys("l", "x")

      assert.spy(callback).called()
    end)

    it("supports rhs string", function()
      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "l", "o42<esc>")

      feedkeys("l", "x")

      h.assert_buf_lines(popup.bufnr, {
        "",
        "42",
      })
    end)

    it("supports o.remap=true", function()
      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "k", "o42<Esc>")
      popup:map("n", "l", "k", { remap = true })

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(popup.bufnr, {
        "",
        "42",
        "42",
      })
    end)

    it("supports o.remap=false", function()
      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "k", "o42<Esc>")
      popup:map("n", "l", "k", { remap = false })

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(popup.bufnr, {
        "",
        "42",
      })
    end)
  end)

  h.describe_flipping_feature("lua_keymap", "method :unmap", function()
    it("supports lhs string", function()
      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "l", "o42<esc>")

      popup:unmap("n", "l")

      feedkeys("l", "x")

      h.assert_buf_lines(popup.bufnr, {
        "",
      })
    end)

    it("supports lhs table", function()
      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "k", "o42<esc>")
      popup:map("n", "l", "o42<esc>")

      popup:unmap("n", { "k", "l" })

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(popup.bufnr, {
        "",
      })
    end)
  end)
end)
