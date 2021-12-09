local Menu = require("nui.menu")
local helper = require("tests.nui")
local spy = require("luassert.spy")

local feedkeys = helper.feedkeys

describe("nui.menu", function()
  local callbacks
  local popup_options

  before_each(function()
    callbacks = {
      on_change = function() end,
    }

    popup_options = {
      relative = "win",
      position = "50%",
    }
  end)

  it("calls o.on_change item focus is changed", function()
    local on_change = spy.on(callbacks, "on_change")

    local lines = {
      Menu.item("Item 1", { id = 1 }),
      Menu.item("Item 2", { id = 2 }),
    }

    local menu = Menu(popup_options, {
      lines = lines,
      on_change = on_change,
    })

    menu:mount()

    -- initial focus
    assert.spy(on_change).called_with(lines[1])
    on_change:clear()

    feedkeys("j", "x")
    assert.spy(on_change).called_with(lines[2])
    on_change:clear()

    feedkeys("j", "x")
    assert.spy(on_change).called_with(lines[1])
    on_change:clear()

    feedkeys("k", "x")
    assert.spy(on_change).called_with(lines[2])
    on_change:clear()
  end)
end)
