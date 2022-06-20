pcall(require, "luacov")

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
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
    it("works before :mount", function()
      local callback = spy.new(function() end)

      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:map("n", "l", function()
        callback()
      end)

      popup:mount()

      feedkeys("l", "x")

      assert.spy(callback).called()
    end)

    it("works after :mount", function()
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

    it("throws if .bufnr is nil", function()
      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup.bufnr = nil

      local ok, result = pcall(function()
        popup:map("n", "l", function() end)
      end)

      eq(ok, false)
      eq(type(string.match(result, "buffer not found")), "string")
    end)
  end)

  h.describe_flipping_feature("lua_keymap", "method :unmap", function()
    it("works before :mount", function()
      local callback = spy.new(function() end)

      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:map("n", "l", function()
        callback()
      end)

      popup:unmap("n", "l")

      popup:mount()

      feedkeys("l", "x")

      assert.spy(callback).not_called()
    end)

    it("works after :mount", function()
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

      popup:unmap("n", "l")

      feedkeys("l", "x")

      assert.spy(callback).not_called()
    end)

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

    it("throws if .bufnr is nil", function()
      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup.bufnr = nil

      local ok, result = pcall(function()
        popup:unmap("n", "l")
      end)

      eq(ok, false)
      eq(type(string.match(result, "buffer not found")), "string")
    end)
  end)

  h.describe_flipping_feature("lua_autocmd", "method :on", function()
    it("works before :mount", function()
      local callback = spy.new(function() end)

      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:on(event.InsertEnter, function()
        callback()
      end)

      popup:mount()

      feedkeys("i", "x")
      feedkeys("<esc>", "x")

      assert.spy(callback).called()
    end)

    it("works after :mount", function()
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

      popup:on(event.InsertEnter, function()
        callback()
      end)

      feedkeys("i", "x")
      feedkeys("<esc>", "x")

      assert.spy(callback).called()
    end)

    it("throws if .bufnr is nil", function()
      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup.bufnr = nil

      local ok, result = pcall(function()
        popup:on(event.InsertEnter, function() end)
      end)

      eq(ok, false)
      eq(type(string.match(result, "buffer not found")), "string")
    end)
  end)

  h.describe_flipping_feature("lua_autocmd", "method :off", function()
    it("works before :mount", function()
      local callback = spy.new(function() end)

      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup:on(event.InsertEnter, function()
        callback()
      end)

      popup:off(event.InsertEnter)

      popup:mount()

      feedkeys("i", "x")
      feedkeys("<esc>", "x")

      assert.spy(callback).not_called()
    end)

    it("works after :mount", function()
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

      popup:on(event.InsertEnter, function()
        callback()
      end)

      popup:off(event.InsertEnter)

      feedkeys("i", "x")
      feedkeys("<esc>", "x")

      assert.spy(callback).not_called()
    end)

    it("throws if .bufnr is nil", function()
      popup = Popup({
        enter = true,
        position = "50%",
        size = {
          height = "60%",
          width = "80%",
        },
      })

      popup.bufnr = nil

      local ok, result = pcall(function()
        popup:off()
      end)

      eq(ok, false)
      eq(type(string.match(result, "buffer not found")), "string")
    end)
  end)

  describe("method :set_layout", function()
    local function assert_size(size, border_size)
      if border_size and type(border_size) ~= "table" then
        border_size = {
          width = size.width + 2,
          height = size.height + 2,
        }
      end

      local win_config = vim.api.nvim_win_get_config(popup.winid)
      eq(win_config.width, size.width)
      eq(win_config.height, size.height)

      if popup.border.winid then
        local border_win_config = vim.api.nvim_win_get_config(popup.border.winid)
        eq(border_win_config.width, border_size.width)
        eq(border_win_config.height, border_size.height)
      end
    end

    local function assert_position(position)
      local win_config = vim.api.nvim_win_get_config(popup.winid)
      eq(win_config.win, popup.border.winid or vim.api.nvim_get_current_win())

      local row, col = unpack(vim.api.nvim_win_get_position(popup.winid))

      if popup.border.winid then
        eq(row, position.row + 1)
        eq(col, position.col + 1)

        local border_row, border_col = unpack(vim.api.nvim_win_get_position(popup.border.winid))

        eq(border_row, position.row)
        eq(border_col, position.col)
      else
        eq(row, position.row)
        eq(col, position.col)
      end
    end

    it("can change size (w/ simple border)", function()
      local size = {
        width = 2,
        height = 1,
      }

      popup = Popup({
        position = "50%",
        size = size,
      })

      popup:mount()

      eq(type(popup.border.winid), "nil")

      assert_size(size)

      local new_size = {
        width = size.width + 2,
        height = size.height + 2,
      }

      popup:set_layout({ size = new_size })

      assert_size(new_size)
    end)

    it("can change size (w/ complex border)", function()
      local hl_group = "NuiPopupTest"
      local style = h.popup.create_border_style_map_with_tuple(hl_group)

      local size = {
        width = 2,
        height = 1,
      }

      popup = Popup({
        ns_id = vim.api.nvim_create_namespace("NuiTest"),
        border = {
          style = style,
          padding = { 0 },
        },
        position = "50%",
        size = size,
      })

      popup:mount()

      eq(type(popup.border.winid), "number")

      assert_size(size, true)
      h.popup.assert_border_lines({
        size = size,
        border = { style = style },
      }, popup.border.bufnr)
      h.popup.assert_border_highlight({
        size = size,
        ns_id = popup.ns_id,
      }, popup.border.bufnr, hl_group)

      local new_size = {
        width = size.width + 2,
        height = size.height + 2,
      }

      popup:set_layout({ size = new_size })

      assert_size(new_size, true)
      h.popup.assert_border_lines({
        size = new_size,
        border = { style = style },
      }, popup.border.bufnr)
      h.popup.assert_border_highlight({
        size = new_size,
        ns_id = popup.ns_id,
      }, popup.border.bufnr, hl_group)
    end)

    it("can change position (w/ simple border)", function()
      local position = {
        row = 0,
        col = 0,
      }

      popup = Popup({
        position = position,
        size = {
          width = 4,
          height = 2,
        },
      })

      popup:mount()

      eq(type(popup.border.winid), "nil")

      assert_position(position)

      local new_position = {
        row = position.row + 2,
        col = position.col + 2,
      }

      popup:set_layout({ position = new_position })

      assert_position(new_position)
    end)

    it("can change position (w/ complex border)", function()
      local hl_group = "NuiPopupTest"
      local style = h.popup.create_border_style_map_with_tuple(hl_group)

      local position = {
        row = 0,
        col = 0,
      }

      popup = Popup({
        ns_id = vim.api.nvim_create_namespace("NuiTest"),
        border = {
          style = style,
          padding = { 0 },
        },
        position = position,
        size = {
          width = 4,
          height = 2,
        },
      })

      popup:mount()

      eq(type(popup.border.winid), "number")

      assert_position(position)

      local new_position = {
        row = position.row + 2,
        col = position.col + 2,
      }

      popup:set_layout({ position = new_position })

      assert_position(new_position)
    end)

    it("throws if missing config 'relative'", function()
      popup = Popup({})

      local ok, result = pcall(function()
        popup:set_layout({})
      end)

      eq(ok, false)
      eq(type(string.match(result, "missing layout config: relative")), "string")
    end)

    it("throws if missing config 'size'", function()
      popup = Popup({})

      local ok, result = pcall(function()
        popup:set_layout({
          relative = "win",
        })
      end)

      eq(ok, false)
      eq(type(string.match(result, "missing layout config: size")), "string")
    end)

    it("throws if missing config 'position'", function()
      popup = Popup({})

      local ok, result = pcall(function()
        popup:set_layout({
          relative = "win",
          size = "50%",
        })
      end)

      eq(ok, false)
      eq(type(string.match(result, "missing layout config: position")), "string")
    end)
  end)

  describe("method :mount", function()
    it("throws if layout is not ready", function()
      popup = Popup({})

      local ok, result = pcall(function()
        popup:mount()
      end)

      eq(ok, false)
      eq(type(string.match(result, "layout is not ready")), "string")
    end)
  end)
end)
