pcall(require, "luacov")

local Line = require("nui.line")
local Text = require("nui.text")
local h = require("tests.nui")

local eq = h.eq

describe("nui.line", function()
  it("can accept initial nui.text objects", function()
    local t1, t2 = Text("One"), Text("Two")
    local line = Line({ t1, t2 })

    eq(#line._texts, 2)
  end)

  describe("method :append", function()
    it("returns nui.text for string parameter", function()
      local line = Line()
      local text = line:append("One")

      eq(type(text.content), "function")
    end)

    it("returns nui.text for nui.text parameter", function()
      local line = Line()
      local text = Text("One")
      local ret_text = line:append(text)

      eq(text == ret_text, true)
      eq(type(ret_text.content), "function")
    end)

    it("stores and returns nui.text with same reference", function()
      local line = Line()

      local text_one = line:append("One")

      eq(line._texts[1] == text_one, true)

      local text_two = Text("Two")
      local ret_text_two = line:append(text_two)

      eq(text_two == ret_text_two, true)
      eq(line._texts[2] == text_two, true)
      eq(line._texts[2] == ret_text_two, true)
    end)
  end)

  describe("method :content", function()
    it("returns whole text content", function()
      local line = Line()
      line:append("One")
      line:append("Two")

      eq(line:content(), "OneTwo")
    end)
  end)

  describe("method", function()
    local winid, bufnr

    before_each(function()
      winid = vim.api.nvim_get_current_win()
      bufnr = vim.api.nvim_create_buf(false, true)

      vim.api.nvim_win_set_buf(winid, bufnr)
    end)

    describe(":highlight", function()
      local hl_group, ns, ns_id
      local linenr
      local t1, t2, t3
      local line

      before_each(function()
        hl_group = "NuiTextTest"
        ns = "NuiTest"
        ns_id = vim.api.nvim_create_namespace(ns)

        linenr = 1

        t1 = Text("One")
        t2 = Text("Two", hl_group)
        t3 = Text("Three")

        line = Line({ t1, t2, t3 })
      end)

      local function assert_highlight()
        local extmarks = h.get_line_extmarks(bufnr, ns_id, linenr)

        eq(#extmarks, 1)
        eq(extmarks[1][3], t1:length())
        h.assert_extmark(extmarks[1], linenr, t2:content(), hl_group)
      end

      it("is applied with :render", function()
        line:render(bufnr, ns_id, linenr)

        assert_highlight()
      end)

      it("can highlight existing buffer line", function()
        vim.api.nvim_buf_set_lines(bufnr, linenr - 1, -1, false, { t1:content() .. t2:content() .. t3:content() })

        line:highlight(bufnr, ns_id, linenr)

        assert_highlight()
      end)
    end)

    describe(":render", function()
      it("works", function()
        local linenr = 1

        local line = Line()
        line:append("4")
        line:append("2")
        line:render(bufnr, -1, linenr)

        eq(vim.api.nvim_buf_get_lines(bufnr, linenr - 1, linenr, false), {
          "42",
        })
      end)
    end)
  end)
end)
