pcall(require, "luacov")

local Popup = require("nui.popup")
local h = require("tests.nui")
local spy = require("luassert.spy")

local eq, feedkeys = h.eq, h.feedkeys

describe("nui.popup", function()
  it("supports o.bufnr (unmanaed buffer)", function()
    local bufnr = vim.api.nvim_create_buf(false, true)

    local lines = {
      "a",
      "b",
      "c",
    }

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local popup = Popup({
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

    local popup = Popup({
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

    local popup = Popup({
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
    local popup = Popup({
      position = "50%",
      size = {
        height = "60%",
        width = "80%",
      },
    })

    eq(type(popup.ns_id), "number")
    eq(popup.ns_id > 0, true)
  end)

  describe("method :map", function()
    it("supports function", function()
      local callback = spy.new(function() end)

      local popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "c", function()
        callback()
      end)

      feedkeys("c", "x")

      assert.spy(callback).called()
    end)

    it("supports string", function()
      local popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "c", "<cmd>read !echo 42<CR>")

      feedkeys("c", "x")

      h.assert_buf_lines(popup.bufnr, {
        "",
        "42",
      })
    end)

    it("supports o.remap=true", function()
      local popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "n", "o<Esc>")
      popup:map("n", "l", "n", { remap = true })

      feedkeys("n", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(popup.bufnr, {
        "",
        "",
        "",
      })
    end)

    it("supports o.remap=false", function()
      local popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "n", "o<Esc>")
      popup:map("n", "l", "n", { remap = false })

      feedkeys("n", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(popup.bufnr, {
        "",
        "",
      })
    end)
  end)

  describe("method :unmap", function()
    it("works", function()
      local popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:mount()

      popup:map("n", "c", "<cmd>read !echo 42<CR>")

      popup:unmap("n", "c")

      feedkeys("c", "x")

      h.assert_buf_lines(popup.bufnr, { "" })
    end)
  end)
end)
