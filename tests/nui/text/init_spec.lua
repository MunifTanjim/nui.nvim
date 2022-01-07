pcall(require, "luacov")

local Text = require("nui.text")
local h = require("tests.nui")
local spy = require("luassert.spy")

local eq, tbl_omit = h.eq, h.tbl_omit

describe("nui.text", function()
  local multibyte_char

  before_each(function()
    multibyte_char = "║"
  end)

  it("can clone nui.text object", function()
    local content = "42"
    local hl_group = "NuiTextTest"

    local t1 = Text(content, hl_group)

    local t2 = Text(t1)
    eq(t1:content(), t2:content())
    eq(t1.extmark, t2.extmark)

    t2.extmark.id = 42
    local t3 = Text(t2)
    eq(t2:content(), t3:content())
    eq(tbl_omit(t2.extmark, { "id" }), t3.extmark)
  end)

  describe("method :set", function()
    it("works", function()
      local content = "42"
      local hl_group = "NuiTextTest"
      local text = Text(content, hl_group)

      eq(text:content(), content)
      eq(text:length(), 2)
      eq(text.extmark, {
        hl_group = hl_group,
      })

      text:set("3")
      eq(text:content(), "3")
      eq(text:length(), 1)
      eq(text.extmark, {
        hl_group = hl_group,
      })

      text:set("3", {
        hl_group = hl_group,
      })
      eq(text:content(), "3")
      eq(text.extmark, {
        hl_group = hl_group,
      })
    end)
  end)

  describe("method :content", function()
    it("works", function()
      local content = "42"
      local text = Text(content)
      eq(text:content(), content)

      local multibyte_content = multibyte_char
      local multibyte_text = Text(multibyte_content)
      eq(multibyte_text:content(), multibyte_content)
    end)
  end)

  describe("method :length", function()
    it("works", function()
      local content = "42"
      local text = Text(content)
      eq(text:length(), 2)
      eq(text:length(), vim.fn.strlen(content))

      local multibyte_content = multibyte_char
      local multibyte_text = Text(multibyte_content)
      eq(multibyte_text:length(), 3)
      eq(multibyte_text:length(), vim.fn.strlen(multibyte_content))
    end)
  end)

  describe("method :width", function()
    it("works", function()
      local content = "42"
      local text = Text(content)
      eq(text:width(), 2)
      eq(text:width(), vim.fn.strwidth(content))

      local multibyte_content = multibyte_char
      local multibyte_text = Text(multibyte_content)
      eq(multibyte_text:width(), 1)
      eq(multibyte_text:width(), vim.fn.strwidth(multibyte_content))
    end)
  end)

  describe("method", function()
    local winid, bufnr
    local initial_lines

    before_each(function()
      winid = vim.api.nvim_get_current_win()
      bufnr = vim.api.nvim_create_buf(false, true)

      vim.api.nvim_win_set_buf(winid, bufnr)

      initial_lines = { "  1", multibyte_char .. " 2", "  3" }
    end)

    local function reset_lines(lines)
      initial_lines = lines or initial_lines
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, initial_lines)
    end

    describe(":highlight", function()
      local hl_group, ns, ns_id
      local linenr, byte_start
      local text

      before_each(function()
        hl_group = "NuiTextTest"
        ns = "NuiTest"
        ns_id = vim.api.nvim_create_namespace(ns)
      end)

      local function assert_highlight()
        local extmarks = h.get_line_extmarks(bufnr, ns_id, linenr)

        eq(#extmarks, 1)
        eq(extmarks[1][3], byte_start)
        h.assert_extmark(extmarks[1], linenr, text:content(), hl_group)
      end

      it("is applied with :render", function()
        reset_lines()
        linenr, byte_start = 1, 0
        text = Text("a", hl_group)
        text:render(bufnr, ns_id, linenr, byte_start)
        assert_highlight()
      end)

      it("is applied with :render_char", function()
        reset_lines()
        linenr, byte_start = 1, 0
        text = Text(multibyte_char, hl_group)
        text:render_char(bufnr, ns_id, linenr, byte_start)
        assert_highlight()
      end)

      it("can highlight existing buffer text", function()
        reset_lines()
        linenr, byte_start = 2, 0
        text = Text(initial_lines[linenr], hl_group)
        text:highlight(bufnr, ns_id, linenr, byte_start)
        assert_highlight()
      end)

      it("does not create multiple extmarks", function()
        reset_lines()
        linenr, byte_start = 2, 0
        text = Text(initial_lines[linenr], hl_group)

        text:highlight(bufnr, ns_id, linenr, byte_start)
        assert_highlight()
        text:highlight(bufnr, ns_id, linenr, byte_start)
        assert_highlight()
        text:highlight(bufnr, ns_id, linenr, byte_start)
        assert_highlight()
      end)
    end)

    describe(":render", function()
      it("works on line with singlebyte characters", function()
        reset_lines()

        local text = Text("a")

        spy.on(text, "highlight")

        text:render(bufnr, -1, 1, 1)

        assert.spy(text.highlight).was_called(1)
        assert.spy(text.highlight).was_called_with(text, bufnr, -1, 1, 1)

        h.assert_buf_lines(bufnr, {
          " a1",
          initial_lines[2],
          initial_lines[3],
        })
      end)

      it("works on line with multibyte characters", function()
        reset_lines()

        local text = Text("a")

        spy.on(text, "highlight")

        text:render(bufnr, -1, 2, vim.fn.strlen(multibyte_char))

        assert.spy(text.highlight).was_called(1)
        assert.spy(text.highlight).was_called_with(text, bufnr, -1, 2, vim.fn.strlen(multibyte_char))

        h.assert_buf_lines(bufnr, {
          initial_lines[1],
          multibyte_char .. "a2",
          initial_lines[3],
        })
      end)
    end)

    describe(":render_char", function()
      it("works on line with singlebyte characters", function()
        reset_lines()

        local text = Text("a")

        spy.on(text, "highlight")

        text:render_char(bufnr, -1, 1, 1)

        assert.spy(text.highlight).was_called(1)
        assert.spy(text.highlight).was_called_with(text, bufnr, -1, 1, 1)

        h.assert_buf_lines(bufnr, {
          " a1",
          initial_lines[2],
          initial_lines[3],
        })
      end)

      it("works on line with multibyte characters", function()
        reset_lines()

        local text = Text("a")

        spy.on(text, "highlight")

        text:render_char(bufnr, -1, 2, 1)

        assert.spy(text.highlight).was_called(1)
        assert.spy(text.highlight).was_called_with(text, bufnr, -1, 2, vim.fn.strlen(multibyte_char))

        h.assert_buf_lines(bufnr, {
          initial_lines[1],
          multibyte_char .. "a2",
          initial_lines[3],
        })
      end)
    end)
  end)
end)
