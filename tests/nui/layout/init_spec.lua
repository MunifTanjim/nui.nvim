pcall(require, "luacov")

local Layout = require("nui.layout")
local Popup = require("nui.popup")
local h = require("tests.nui")
local spy = require("luassert.spy")

local eq = h.eq

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
