pcall(require, "luacov")

local Input = require("nui.input")
local Text = require("nui.text")
local h = require("tests.nui")

local eq, feedkeys, tbl_pick = h.eq, h.feedkeys, h.tbl_pick

-- Input's functionalities are not testable using headless nvim.
-- Not sure what to do about it.

describe("nui.input", function()
  local parent_winid, parent_bufnr
  local popup_options

  before_each(function()
    parent_winid = vim.api.nvim_get_current_win()
    parent_bufnr = vim.api.nvim_get_current_buf()

    popup_options = {
      relative = "win",
      position = "50%",
      size = 20,
    }
  end)

  pending("o.prompt", function()
    it("supports NuiText", function()
      local prompt_text = "> "
      local hl_group = "NuiInputTest"

      local input = Input(popup_options, {
        prompt = Text(prompt_text, hl_group),
      })

      input:mount()

      eq(vim.api.nvim_buf_get_lines(input.bufnr, 0, -1, false), { prompt_text })

      local linenr = 1
      local line = vim.api.nvim_buf_get_lines(input.bufnr, linenr - 1, linenr, false)[linenr]
      local byte_start = string.find(line, prompt_text)

      local extmarks = vim.api.nvim_buf_get_extmarks(input.bufnr, input.ns_id, linenr - 1, linenr, {
        details = true,
      })

      eq(type(byte_start), "number")

      eq(#extmarks, 1)
      eq(extmarks[1][2], linenr - 1)
      eq(extmarks[1][4].end_col - extmarks[1][3], #prompt_text)
      eq(tbl_pick(extmarks[1][4], { "end_row", "hl_group" }), {
        end_row = linenr - 1,
        hl_group = hl_group,
      })
    end)
  end)

  describe("cursor_position_patch", function()
    local initial_cursor

    local function setup()
      vim.api.nvim_buf_set_lines(parent_bufnr, 0, -1, false, {
        "1 nui.nvim",
        "2 nui.nvim",
        "3 nui.nvim",
      })
      initial_cursor = { 2, 4 }
      vim.api.nvim_win_set_cursor(parent_winid, initial_cursor)
    end

    it("works after submitting from insert mode", function()
      setup()

      local done = false
      local input = Input(popup_options, {
        on_submit = function()
          done = true
        end,
      })

      input:mount()

      feedkeys("<cr>", "x")

      vim.fn.wait(1000, function()
        return done
      end)

      eq(done, true)
      eq(vim.api.nvim_win_get_cursor(parent_winid), initial_cursor)
    end)

    it("works after submitting from normal mode", function()
      setup()

      local done = false
      local input = Input(popup_options, {
        on_submit = function()
          done = true
        end,
      })

      input:mount()

      feedkeys("<esc><cr>", "x")

      vim.fn.wait(1000, function()
        return done
      end)

      eq(done, true)
      eq(vim.api.nvim_win_get_cursor(parent_winid), initial_cursor)
    end)

    it("works after closing from insert mode", function()
      setup()

      local done = false
      local input = Input(popup_options, {
        on_close = function()
          done = true
        end,
      })

      input:mount()

      input:map("i", "<esc>", input.input_props.on_close, { nowait = true, noremap = true })

      feedkeys("i<esc>", "x")

      vim.fn.wait(1000, function()
        return done
      end)

      eq(done, true)
      eq(vim.api.nvim_win_get_cursor(parent_winid), initial_cursor)
    end)

    it("works after closing from normal mode", function()
      setup()

      local done = false
      local input = Input(popup_options, {
        on_close = function()
          done = true
        end,
      })

      input:mount()

      input:map("n", "<esc>", input.input_props.on_close, { nowait = true, noremap = true })

      feedkeys("<esc>", "x")

      vim.fn.wait(1000, function()
        return done
      end)

      eq(done, true)
      eq(vim.api.nvim_win_get_cursor(parent_winid), initial_cursor)
    end)
  end)
end)
