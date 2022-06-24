pcall(require, "luacov")

local Layout = require("nui.layout")
local Popup = require("nui.popup")
local h = require("tests.nui")
local spy = require("luassert.spy")

local eq, tbl_pick = h.eq, h.tbl_pick

local function create_popups(...)
  local popups = {}
  for _, popup_options in ipairs({ ... }) do
    table.insert(popups, Popup(popup_options))
  end
  return popups
end

describe("nui.layout", function()
  local layout

  after_each(function()
    layout:unmount()
  end)

  describe("o.size", function()
    local function assert_size(size)
      local win_config = vim.api.nvim_win_get_config(layout.winid)

      eq(tbl_pick(win_config, { "width", "height" }), {
        width = math.floor(size.width),
        height = math.floor(size.height),
      })
    end

    it("supports number", function()
      local size = 20

      layout = Layout({
        position = "50%",
        size = size,
      }, {})

      layout:mount()

      assert_size({ width = size, height = size })
    end)

    it("supports percentage string", function()
      local percentage = 50

      layout = Layout({
        position = "50%",
        size = string.format("%s%%", percentage),
      }, {})

      local winid = vim.api.nvim_get_current_win()
      local win_width = vim.api.nvim_win_get_width(winid)
      local win_height = vim.api.nvim_win_get_height(winid)

      layout:mount()

      assert_size({
        width = win_width * percentage / 100,
        height = win_height * percentage / 100,
      })
    end)

    it("supports table", function()
      local width = 10
      local height_percentage = 50

      layout = Layout({
        position = "50%",
        size = {
          width = width,
          height = string.format("%s%%", height_percentage),
        },
      }, {})

      local winid = vim.api.nvim_get_current_win()
      local win_height = vim.api.nvim_win_get_height(winid)

      layout:mount()

      assert_size({
        width = width,
        height = win_height * height_percentage / 100,
      })
    end)
  end)

  describe("method :mount", function()
    it("mounts all components", function()
      local p1, p2 = unpack(create_popups({}, {}))

      local p1_mount = spy.on(p1, "mount")
      local p2_mount = spy.on(p2, "mount")

      layout = Layout(
        {
          position = "50%",
          size = {
            height = 20,
            width = 100,
          },
        },
        Layout.Box({
          Layout.Box(p1, { size = "50%" }),
          Layout.Box(p2, { size = "50%" }),
        })
      )

      layout:mount()

      eq(type(layout.bufnr), "number")
      eq(type(layout.winid), "number")

      assert.spy(p1_mount).was_called()
      assert.spy(p2_mount).was_called()
    end)

    it("is idempotent", function()
      local p1, p2 = unpack(create_popups({}, {}))

      local p1_mount = spy.on(p1, "mount")
      local p2_mount = spy.on(p2, "mount")

      layout = Layout(
        {
          position = "50%",
          size = 20,
        },
        Layout.Box({
          Layout.Box(p1, { size = "50%" }),
          Layout.Box(p2, { size = "50%" }),
        })
      )

      layout:mount()

      assert.spy(p1_mount).was_called(1)
      assert.spy(p2_mount).was_called(1)

      layout:mount()

      assert.spy(p1_mount).was_called(1)
      assert.spy(p2_mount).was_called(1)
    end)
  end)
end)
