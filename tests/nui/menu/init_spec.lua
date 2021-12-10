local Menu = require("nui.menu")
local helper = require("tests.nui")
local spy = require("luassert.spy")

local eq, feedkeys = helper.eq, helper.feedkeys

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

  describe("size", function()
    it("respects o.min_width", function()
      local min_width = 3

      local items = {
        Menu.item("A"),
        Menu.separator("*"),
        Menu.item("B"),
      }

      local menu = Menu(popup_options, {
        lines = items,
        min_width = min_width,
      })

      menu:mount()

      eq(vim.api.nvim_win_get_width(menu.winid), min_width)

      eq(vim.api.nvim_buf_get_lines(menu.bufnr, 0, -1, false), {
        "A",
        " * ",
        "B",
      })
    end)

    it("respects o.max_width", function()
      local max_width = 6

      local items = {
        Menu.item("Item 1"),
        Menu.separator("*"),
        Menu.item("Item Number Two"),
      }

      local menu = Menu(popup_options, {
        lines = items,
        max_width = max_width,
      })

      menu:mount()

      eq(vim.api.nvim_win_get_width(menu.winid), max_width)

      eq(vim.api.nvim_buf_get_lines(menu.bufnr, 0, -1, false), {
        "Item 1",
        " *    ",
        "Item …",
      })
    end)

    it("respects o.min_height", function()
      local min_height = 3

      local items = {
        Menu.item("A"),
        Menu.separator("*"),
        Menu.item("B"),
      }

      local menu = Menu(popup_options, {
        lines = items,
        min_height = min_height,
      })

      menu:mount()

      eq(vim.api.nvim_win_get_height(menu.winid), min_height)
    end)

    it("respects o.max_height", function()
      local max_height = 2

      local items = {
        Menu.item("A"),
        Menu.separator("*"),
        Menu.item("B"),
      }

      local menu = Menu(popup_options, {
        lines = items,
        max_height = max_height,
      })

      menu:mount()

      eq(vim.api.nvim_win_get_height(menu.winid), max_height)
    end)
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
    assert.spy(on_change).called_with(lines[1], menu)
    on_change:clear()

    feedkeys("j", "x")
    assert.spy(on_change).called_with(lines[2], menu)
    on_change:clear()

    feedkeys("j", "x")
    assert.spy(on_change).called_with(lines[1], menu)
    on_change:clear()

    feedkeys("k", "x")
    assert.spy(on_change).called_with(lines[2], menu)
    on_change:clear()
  end)
end)
