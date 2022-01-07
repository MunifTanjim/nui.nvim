pcall(require, "luacov")

local Popup = require("nui.popup")
local Text = require("nui.text")
local h = require("tests.nui")

local eq = h.eq

describe("nui.popup", function()
  local popup_options = {}

  before_each(function()
    popup_options = {
      ns_id = vim.api.nvim_create_namespace("NuiTest"),
      position = "50%",
      size = {
        height = 2,
        width = 8,
      },
    }
  end)

  describe("border.style", function()
    local function get_border_style_list()
      local function assert_lines(bufnr)
        h.assert_buf_lines(bufnr, {
          "╭────────╮",
          "│        │",
          "│        │",
          "╰────────╯",
        })
      end

      return { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }, assert_lines
    end

    local function get_border_style_map()
      local function assert_lines(bufnr)
        h.assert_buf_lines(bufnr, {
          "╭────────╮",
          "│        │",
          "│        │",
          "╰────────╯",
        })
      end

      return {
        top_left = "╭",
        top = "─",
        top_right = "╮",
        left = "│",
        right = "│",
        bottom_left = "╰",
        bottom = "─",
        bottom_right = "╯",
      },
        assert_lines
    end

    local function get_borer_style_map_with_nui_text(hl_group)
      local style, assert_lines = get_border_style_map()
      for k, v in pairs(style) do
        style[k] = Text(v, hl_group .. "_" .. k)
      end
      return style, assert_lines
    end

    local function get_borer_style_map_with_tuple(hl_group)
      local style, assert_lines = get_border_style_map()
      for k, v in pairs(style) do
        style[k] = { v, hl_group .. "_" .. k }
      end
      return style, assert_lines
    end

    it("supports string name", function()
      popup_options = vim.tbl_deep_extend("force", popup_options, {
        border = {
          style = "rounded",
          padding = { 0 },
        },
      })

      local popup = Popup(popup_options)

      popup:mount()

      h.assert_buf_lines(popup.border.bufnr, {
        "╭────────╮",
        "│        │",
        "│        │",
        "╰────────╯",
      })
    end)

    it("supports list table", function()
      local style, assert_lines = get_border_style_list()

      popup_options = vim.tbl_deep_extend("force", popup_options, {
        border = {
          style = style,
          padding = { 0 },
        },
      })

      local popup = Popup(popup_options)

      popup:mount()

      assert_lines(popup.border.bufnr)
    end)

    it("supports map table", function()
      local style, assert_lines = get_border_style_map()

      popup_options = vim.tbl_deep_extend("force", popup_options, {
        border = {
          style = style,
          padding = { 0 },
        },
      })

      local popup = Popup(popup_options)

      popup:mount()

      assert_lines(popup.border.bufnr)
    end)

    describe("supports highlight", function()
      local function assert_highlight(popup, hl_group)
        local size = popup_options.size

        for linenr = 1, size.height + 2 do
          local is_top_line = linenr == 1
          local is_bottom_line = linenr == size.height + 2

          local extmarks = h.get_line_extmarks(popup.border.bufnr, popup_options.ns_id, linenr)

          eq(#extmarks, (is_top_line or is_bottom_line) and 4 or 2)

          h.assert_extmark(
            extmarks[1],
            linenr,
            nil,
            hl_group .. (is_top_line and "_top_left" or is_bottom_line and "_bottom_left" or "_left")
          )

          if is_top_line or is_bottom_line then
            h.assert_extmark(extmarks[2], linenr, nil, hl_group .. (is_top_line and "_top" or "_bottom"))
            h.assert_extmark(extmarks[3], linenr, nil, hl_group .. (is_top_line and "_top" or "_bottom"))
          end

          h.assert_extmark(
            extmarks[#extmarks],
            linenr,
            nil,
            hl_group .. (is_top_line and "_top_right" or is_bottom_line and "_bottom_right" or "_right")
          )
        end
      end

      it("as (char, hl_group) tuple in map table", function()
        local hl_group = "NuiPopupTest"
        local style, assert_lines = get_borer_style_map_with_tuple(hl_group)

        popup_options = vim.tbl_deep_extend("force", popup_options, {
          border = {
            style = style,
            padding = { 0 },
          },
        })

        local popup = Popup(popup_options)

        popup:mount()

        assert_lines(popup.border.bufnr)
        assert_highlight(popup, hl_group)
      end)

      it("as nui.text in map table", function()
        local hl_group = "NuiPopupTest"
        local style, assert_lines = get_borer_style_map_with_nui_text(hl_group)

        popup_options = vim.tbl_deep_extend("force", popup_options, {
          border = {
            style = style,
            padding = { 0 },
          },
        })

        local popup = Popup(popup_options)

        popup:mount()

        assert_lines(popup.border.bufnr)
        assert_highlight(popup, hl_group)
      end)
    end)
  end)

  describe("border.text", function()
    it("supports simple text", function()
      local text = "popup"

      popup_options = vim.tbl_deep_extend("force", popup_options, {
        border = {
          style = "single",
          text = {
            top = text,
          },
        },
      })

      local popup = Popup(popup_options)

      popup:mount()

      local linenr = 1
      local line = vim.api.nvim_buf_get_lines(popup.border.bufnr, linenr - 1, linenr, false)[linenr]
      local byte_start = string.find(line, text)

      popup:unmount()

      eq(type(byte_start), "number")
    end)

    it("supports nui.text", function()
      local text = "popup"
      local hl_group = "NuiPopupTest"

      popup_options = vim.tbl_deep_extend("force", popup_options, {
        border = {
          style = "single",
          text = {
            top = Text(text, hl_group),
          },
        },
      })

      local popup = Popup(popup_options)

      popup:mount()

      local linenr = 1
      local line = vim.api.nvim_buf_get_lines(popup.border.bufnr, linenr - 1, linenr, false)[linenr]
      local byte_start = string.find(line, text)

      local extmarks = h.get_line_extmarks(popup.border.bufnr, popup_options.ns_id, linenr, byte_start, #text)

      popup:unmount()

      eq(type(byte_start), "number")

      eq(#extmarks, 1)
      h.assert_extmark(extmarks[1], linenr, text, hl_group)
    end)
  end)
end)
