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

  describe("o.position", function()
    local function assert_position(position)
      local row, col = unpack(vim.api.nvim_win_get_position(layout.winid))

      eq(row, math.floor(position.row))
      eq(col, math.floor(position.col))
    end

    it("supports number", function()
      local position = 5

      layout = Layout({
        position = position,
        size = 10,
      }, {})

      layout:mount()

      assert_position({ row = position, col = position })
    end)

    it("supports percentage string", function()
      local size = 10
      local percentage = 50

      layout = Layout({
        position = string.format("%s%%", percentage),
        size = size,
      }, {})

      layout:mount()

      local winid = vim.api.nvim_get_current_win()
      local win_width = vim.api.nvim_win_get_width(winid)
      local win_height = vim.api.nvim_win_get_height(winid)

      assert_position({
        row = (win_height - size) * percentage / 100,
        col = (win_width - size) * percentage / 100,
      })
    end)

    it("supports table", function()
      local size = 10
      local row = 5
      local col_percentage = 50

      layout = Layout({
        position = {
          row = row,
          col = string.format("%s%%", col_percentage),
        },
        size = size,
      }, {})

      layout:mount()

      local winid = vim.api.nvim_get_current_win()
      local win_width = vim.api.nvim_win_get_width(winid)

      assert_position({
        row = row,
        col = (win_width - size) * col_percentage / 100,
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

  describe("box", function()
    it("throws if missing child.size", function()
      local p1, p2 = unpack(create_popups({}, {}))

      local ok, result = pcall(function()
        Layout.Box({
          Layout.Box(p1, { size = "50%" }),
          Layout.Box(p2, {}),
        })
      end)

      eq(ok, false)
      eq(type(string.match(result, "missing child.size")), "string")
    end)

    describe("size (table)", function()
      it("missing height is set to 100% if dir=row", function()
        local p1, p2 = unpack(create_popups({}, {}))

        local box = Layout.Box({
          Layout.Box(p1, { size = { width = "40%" } }),
          Layout.Box(p2, { size = { width = "60%", height = "80%" } }),
        }, { dir = "row" })

        eq(box.box[1].size, {
          width = "40%",
          height = "100%",
        })
        eq(box.box[2].size, {
          width = "60%",
          height = "80%",
        })
      end)

      it("missing width is set to 100% if dir=col", function()
        local p1, p2 = unpack(create_popups({}, {}))

        local box = Layout.Box({
          Layout.Box(p1, { size = { height = "40%" } }),
          Layout.Box(p2, { size = { width = "60%", height = "80%" } }),
        }, { dir = "col" })

        eq(box.box[1].size, {
          width = "100%",
          height = "40%",
        })
        eq(box.box[2].size, {
          width = "60%",
          height = "80%",
        })
      end)
    end)

    describe("size (percentage string)", function()
      it("is set to width if dir=row", function()
        local p1, p2 = unpack(create_popups({}, {}))

        local box = Layout.Box({
          Layout.Box(p1, { size = "40%" }),
          Layout.Box(p2, { size = "60%" }),
        }, { dir = "row" })

        eq(box.box[1].size, {
          width = "40%",
          height = "100%",
        })
        eq(box.box[2].size, {
          width = "60%",
          height = "100%",
        })
      end)

      it("is set to height if dir=col", function()
        local p1, p2 = unpack(create_popups({}, {}))

        local box = Layout.Box({
          Layout.Box(p1, { size = "40%" }),
          Layout.Box(p2, { size = "60%" }),
        }, { dir = "col" })

        eq(box.box[1].size, {
          width = "100%",
          height = "40%",
        })
        eq(box.box[2].size, {
          width = "100%",
          height = "60%",
        })
      end)
    end)
  end)

  it("can correctly process layout", function()
    local winid = vim.api.nvim_get_current_win()
    local win_width = vim.api.nvim_win_get_width(winid)
    local win_height = vim.api.nvim_win_get_height(winid)

    local p1, p2, p3, p4 = unpack(create_popups({}, {}, {
      border = {
        style = "rounded",
      },
    }, {}))

    layout = Layout(
      {
        position = 0,
        size = "100%",
      },
      Layout.Box({
        Layout.Box(p1, { size = "20%" }),
        Layout.Box({
          Layout.Box(p3, { size = "50%" }),
          Layout.Box(p4, { size = "50%" }),
        }, { dir = "col", size = "60%" }),
        Layout.Box(p2, { size = "20%" }),
      }, { dir = "row" })
    )

    layout:mount()

    local function assert_layout(component, expected)
      eq(type(component.bufnr), "number")
      eq(type(component.winid), "number")

      local row, col = unpack(vim.api.nvim_win_get_position(component.winid))
      eq(row, expected.position.row)
      eq(col, expected.position.col)

      local expected_width, expected_height = expected.size.width, expected.size.height
      if component.border then
        expected_width = expected_width - component.border._.size_delta.width
        expected_height = expected_height - component.border._.size_delta.height
      end
      eq(vim.api.nvim_win_get_width(component.winid), expected_width)
      eq(vim.api.nvim_win_get_height(component.winid), expected_height)
    end

    assert_layout(p1, {
      position = {
        row = 0,
        col = 0,
      },
      size = {
        width = win_width * 20 / 100,
        height = win_height,
      },
    })

    assert_layout(p3, {
      position = {
        row = 0,
        col = win_width * 20 / 100,
      },
      size = {
        width = win_width * 60 / 100,
        height = win_height * 50 / 100,
      },
    })

    assert_layout(p4, {
      position = {
        row = win_height * 50 / 100,
        col = win_width * 20 / 100,
      },
      size = {
        width = win_width * 60 / 100,
        height = win_height * 50 / 100,
      },
    })

    assert_layout(p2, {
      position = {
        row = 0,
        col = win_width * 20 / 100 + win_width * 60 / 100,
      },
      size = {
        width = win_width * 20 / 100,
        height = win_height,
      },
    })
  end)
end)
