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

local function percent(number, percentage)
  return math.floor(number * percentage / 100)
end

local function get_assert_component(layout)
  local expected_winid = layout.winid
  assert(expected_winid, "missing layout.winid, forgot to mount it?")

  return function(component, expected)
    eq(type(component.bufnr), "number")
    eq(type(component.winid), "number")

    local win_config = vim.api.nvim_win_get_config(component.winid)
    eq(win_config.relative, "win")
    eq(win_config.win, expected_winid)

    local row, col = win_config.row[vim.val_idx], win_config.col[vim.val_idx]
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

    it("throws if missing config 'size'", function()
      local ok, result = pcall(function()
        layout = Layout({}, {})
      end)

      eq(ok, false)
      eq(type(string.match(result, "missing layout config: size")), "string")
    end)

    it("throws if missing config 'position'", function()
      local ok, result = pcall(function()
        layout = Layout({
          size = "50%",
        }, {})
      end)

      eq(ok, false)
      eq(type(string.match(result, "missing layout config: position")), "string")
    end)
  end)

  describe("box", function()
    it("requires child.size if child.grow is missing", function()
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

    it("does not require child.size if child.grow is present", function()
      local p1, p2 = unpack(create_popups({}, {}))

      local ok = pcall(function()
        Layout.Box({
          Layout.Box(p1, { size = "50%" }),
          Layout.Box(p2, { grow = 1 }),
        })
      end)

      eq(ok, true)
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

  describe("method :update", function()
    local winid, win_width, win_height
    local p1, p2, p3, p4
    local assert_component

    before_each(function()
      winid = vim.api.nvim_get_current_win()
      win_width = vim.api.nvim_win_get_width(winid)
      win_height = vim.api.nvim_win_get_height(winid)

      p1, p2, p3, p4 = unpack(create_popups({}, {}, {
        border = {
          style = "rounded",
        },
      }, {}))
    end)

    local function get_initial_layout(config)
      return Layout(
        config,
        Layout.Box({
          Layout.Box(p1, { size = "20%" }),
          Layout.Box({
            Layout.Box(p3, { size = "50%" }),
            Layout.Box(p4, { size = "50%" }),
          }, { dir = "col", size = "60%" }),
          Layout.Box(p2, { size = "20%" }),
        }, { dir = "row" })
      )
    end

    local function assert_layout_config(config)
      local relative, position, size = config.relative, config.position, config.size

      local win_config = vim.api.nvim_win_get_config(layout.winid)
      eq(win_config.relative, relative.type)
      eq(win_config.win, relative.winid)

      local row, col = unpack(vim.api.nvim_win_get_position(layout.winid))
      eq(row, position.row)
      eq(col, position.col)

      eq(vim.api.nvim_win_get_width(layout.winid), size.width)
      eq(vim.api.nvim_win_get_height(layout.winid), size.height)
    end

    local function assert_initial_layout_components()
      local size = {
        width = vim.api.nvim_win_get_width(layout.winid),
        height = vim.api.nvim_win_get_height(layout.winid),
      }

      assert_component(p1, {
        position = {
          row = 0,
          col = 0,
        },
        size = {
          width = percent(size.width, 20),
          height = size.height,
        },
      })

      assert_component(p3, {
        position = {
          row = 0,
          col = percent(size.width, 20),
        },
        size = {
          width = percent(size.width, 60),
          height = percent(size.height, 50),
        },
      })

      assert_component(p4, {
        position = {
          row = percent(size.height, 50),
          col = percent(size.width, 20),
        },
        size = {
          width = percent(size.width, 60),
          height = percent(size.height, 50),
        },
      })

      assert_component(p2, {
        position = {
          row = 0,
          col = percent(size.width, 20) + percent(size.width, 60),
        },
        size = {
          width = percent(size.width, 20),
          height = size.height,
        },
      })
    end

    it("processes layout correctly on mount", function()
      local layout_update_spy = spy.on(Layout, "update")

      layout = get_initial_layout({ position = 0, size = "100%" })

      layout:mount()

      layout_update_spy:revert()
      assert.spy(layout_update_spy).was_called(1)

      local expected_layout_config = {
        relative = {
          type = "win",
          winid = winid,
        },
        position = {
          row = 0,
          col = 0,
        },
        size = {
          width = win_width,
          height = win_height,
        },
      }

      assert_layout_config(expected_layout_config)

      assert_component = get_assert_component(layout)

      assert_initial_layout_components()
    end)

    it("can update layout win_config w/o changing boxes", function()
      layout = get_initial_layout({ position = 0, size = "100%" })

      layout:mount()

      layout:update({
        position = {
          row = 2,
          col = 4,
        },
        size = "80%",
      })

      local expected_layout_config = {
        relative = {
          type = "win",
          winid = winid,
        },
        position = {
          row = 2,
          col = 4,
        },
        size = {
          width = percent(win_width, 80),
          height = percent(win_height, 80),
        },
      }

      assert_layout_config(expected_layout_config)

      assert_component = get_assert_component(layout)

      assert_initial_layout_components()
    end)

    it("can update boxes w/o changing layout win_config", function()
      layout = get_initial_layout({ position = 0, size = "100%" })

      layout:mount()

      layout:update(Layout.Box({
        Layout.Box(p2, { size = "30%" }),
        Layout.Box({
          Layout.Box(p4, { size = "40%" }),
          Layout.Box(p3, { size = "60%" }),
        }, { dir = "row", size = "30%" }),
        Layout.Box(p1, { size = "40%" }),
      }, { dir = "col" }))

      local expected_layout_config = {
        relative = {
          type = "win",
          winid = winid,
        },
        position = {
          row = 0,
          col = 0,
        },
        size = {
          width = win_width,
          height = win_height,
        },
      }

      assert_layout_config(expected_layout_config)

      assert_component = get_assert_component(layout)

      assert_component(p2, {
        position = {
          row = 0,
          col = 0,
        },
        size = {
          width = win_width,
          height = percent(win_height, 30),
        },
      })

      assert_component(p4, {
        position = {
          row = percent(win_height, 30),
          col = 0,
        },
        size = {
          width = percent(win_width, 40),
          height = percent(win_height, 30),
        },
      })

      assert_component(p3, {
        position = {
          row = percent(win_height, 30),
          col = percent(win_width, 40),
        },
        size = {
          width = percent(win_width, 60),
          height = percent(win_height, 30),
        },
      })

      assert_component(p1, {
        position = {
          row = percent(win_height, 30) + percent(win_height, 30),
          col = 0,
        },
        size = {
          width = win_width,
          height = percent(win_height, 40),
        },
      })
    end)

    it("refreshes layout if container size changes", function()
      local popup = Popup({
        position = 0,
        size = "100%",
      })

      popup:mount()

      layout = get_initial_layout({
        relative = {
          type = "win",
          winid = popup.winid,
        },
        position = 0,
        size = "80%",
      })

      layout:mount()

      local expected_layout_config = {
        relative = {
          type = "win",
          winid = popup.winid,
        },
        position = {
          row = 0,
          col = 0,
        },
        size = {
          width = percent(win_width, 80),
          height = percent(win_height, 80),
        },
      }

      assert_layout_config(expected_layout_config)

      assert_component = get_assert_component(layout)

      assert_initial_layout_components()

      popup:set_layout({
        size = "80%",
      })

      layout:update()

      expected_layout_config.size = {
        width = percent(percent(win_width, 80), 80),
        height = percent(percent(win_height, 80), 80),
      }

      assert_layout_config(expected_layout_config)

      assert_initial_layout_components()
    end)

    it("supports child with child.grow", function()
      layout = get_initial_layout({ position = 0, size = "100%" })

      layout:mount()

      layout:update(Layout.Box({
        Layout.Box(p1, { size = "20%" }),
        Layout.Box({
          Layout.Box({}, { size = 4 }),
          Layout.Box(p3, { grow = 1 }),
          Layout.Box({}, { size = 8 }),
          Layout.Box(p4, { grow = 1 }),
        }, { dir = "col", size = "60%" }),
        Layout.Box(p2, { grow = 1 }),
      }, { dir = "row" }))

      local expected_layout_config = {
        relative = {
          type = "win",
          winid = winid,
        },
        position = {
          row = 0,
          col = 0,
        },
        size = {
          width = win_width,
          height = win_height,
        },
      }

      assert_layout_config(expected_layout_config)

      assert_component = get_assert_component(layout)

      assert_component(p1, {
        position = {
          row = 0,
          col = 0,
        },
        size = {
          width = percent(win_width, 20),
          height = win_height,
        },
      })

      assert_component(p3, {
        position = {
          row = 4,
          col = percent(win_width, 20),
        },
        size = {
          width = percent(win_width, 60),
          height = percent(win_height - 4 - 8, 100 / 2),
        },
      })

      assert_component(p4, {
        position = {
          row = 4 + 8 + percent(win_height - 4 - 8, 100 / 2),
          col = percent(win_width, 20),
        },
        size = {
          width = percent(win_width, 60),
          height = percent(win_height - 4 - 8, 100 / 2),
        },
      })

      assert_component(p2, {
        position = {
          row = 0,
          col = percent(win_width, 20) + percent(win_width, 60),
        },
        size = {
          width = percent(win_width, 100 - 20 - 60),
          height = win_height,
        },
      })
    end)
  end)
end)
