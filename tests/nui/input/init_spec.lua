local Input = require("nui.input")
local Text = require("nui.text")
local helper = require("tests.nui")

local eq, tbl_pick = helper.eq, helper.tbl_pick

-- Input's functionalities are not testable using headless nvim.
-- Not sure what to do about it.

pending("nui.input", function()
  local popup_options

  before_each(function()
    popup_options = {
      relative = "win",
      position = "50%",
      size = 20,
    }
  end)

  describe("o.prompt", function()
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
end)
