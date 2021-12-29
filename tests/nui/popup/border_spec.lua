local Popup = require("nui.popup")
local Text = require("nui.text")
local helper = require("tests.nui")

local eq, tbl_pick = helper.eq, helper.tbl_pick

describe("nui.popup", function()
  local popup_options = {}

  before_each(function()
    popup_options = {
      ns_id = vim.api.nvim_create_namespace("NuiTest"),
      position = "50%",
      size = {
        height = "20",
        width = "40",
      },
    }
  end)

  describe("border.style", function()
    local function get_size()
      return { height = 4, width = 8 }
    end

    local function get_border_style_list()
      return { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
    end

    local function get_border_style_map()
      return {
        top_left = "╭",
        top = "─",
        top_right = "╮",
        left = "│",
        right = "│",
        bottom_left = "╰",
        bottom = "─",
        bottom_right = "╯",
      }
    end

    it("supports string name", function()
      local popup = Popup(vim.tbl_deep_extend("force", popup_options, {
        border = {
          style = "rounded",
          padding = { 0 },
        },
        size = get_size(),
      }))

      popup:mount()

      eq(vim.api.nvim_buf_get_lines(popup.border.bufnr, 0, -1, false), {
        "╭────────╮",
        "│        │",
        "│        │",
        "│        │",
        "│        │",
        "╰────────╯",
      })
    end)

    it("supports list table", function()
      local style = get_border_style_list()

      local popup = Popup(vim.tbl_deep_extend("force", popup_options, {
        border = {
          style = style,
          padding = { 0 },
        },
        size = get_size(),
      }))

      popup:mount()

      eq(vim.api.nvim_buf_get_lines(popup.border.bufnr, 0, -1, false), {
        "╭────────╮",
        "│        │",
        "│        │",
        "│        │",
        "│        │",
        "╰────────╯",
      })
    end)

    it("supports map table", function()
      local style = get_border_style_map()

      local popup = Popup(vim.tbl_deep_extend("force", popup_options, {
        border = {
          style = style,
          padding = { 0 },
        },
        size = get_size(),
      }))

      popup:mount()

      eq(vim.api.nvim_buf_get_lines(popup.border.bufnr, 0, -1, false), {
        "╭────────╮",
        "│        │",
        "│        │",
        "│        │",
        "│        │",
        "╰────────╯",
      })
    end)
  end)

  describe("border.text", function()
    it("supports simple text", function()
      local text = "popup"

      local popup = Popup({
        border = {
          style = "single",
          text = {
            top = text,
          },
        },
        position = "50%",
        size = {
          height = "40",
          width = "80",
        },
      })

      popup:mount()

      local linenr = 1
      local line = vim.api.nvim_buf_get_lines(popup.border.bufnr, linenr - 1, linenr, false)[linenr]
      local byte_start = string.find(line, text)

      popup:unmount()

      eq(type(byte_start), "number")
    end)

    it("supports NuiText", function()
      local text = "popup"
      local hl_group = "NuiPopupTest"

      local ns_id = vim.api.nvim_create_namespace("NuiTest")

      local popup = Popup({
        ns_id = ns_id,
        border = {
          style = "single",
          text = {
            top = Text(text, hl_group),
          },
        },
        position = "50%",
        size = {
          height = "40",
          width = "80",
        },
      })

      popup:mount()

      local linenr = 1
      local line = vim.api.nvim_buf_get_lines(popup.border.bufnr, linenr - 1, linenr, false)[linenr]
      local byte_start = string.find(line, text)

      local extmarks = vim.api.nvim_buf_get_extmarks(popup.border.bufnr, ns_id, linenr - 1, linenr, {
        details = true,
      })

      popup:unmount()

      eq(type(byte_start), "number")

      eq(#extmarks, 1)
      eq(extmarks[1][2], linenr - 1)
      eq(extmarks[1][4].end_col - extmarks[1][3], #text)
      eq(tbl_pick(extmarks[1][4], { "end_row", "hl_group" }), {
        end_row = linenr - 1,
        hl_group = hl_group,
      })
    end)
  end)
end)
