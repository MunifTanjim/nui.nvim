pcall(require, "luacov")

local Split = require("nui.split")
local event = require("nui.utils.autocmd").event
local h = require("tests.nui")
local spy = require("luassert.spy")

local eq, feedkeys = h.eq, h.feedkeys

describe("nui.split", function()
  local split

  after_each(function()
    split:unmount()
  end)

  describe("o.size", function()
    for position, dimension in pairs({ top = "height", right = "width", bottom = "height", left = "width" }) do
      it(string.format("is set as %s if o.position=%s", dimension, position), function()
        local size = 20

        split = Split({
          size = size,
          position = position,
        })

        split:mount()

        local nvim_method = string.format("nvim_win_get_%s", dimension)

        eq(vim.api[nvim_method](split.winid), size)
      end)
    end

    it("is optional", function()
      split = Split({
        position = "bottom",
      })

      split:mount()

      eq(type(vim.api.nvim_win_get_height(split.winid)), "number")
    end)
  end)

  it("supports o.relative=win", function()
    local left_half_split = Split({
      size = "50%",
      position = "left",
    })

    left_half_split:mount()

    split = Split({
      size = 20,
      position = "bottom",
      relative = "win",
    })

    split:mount()

    eq(vim.api.nvim_win_get_width(split.winid), vim.o.columns / 2)

    left_half_split:unmount()
  end)

  it("supports o.relative=editor", function()
    local left_half_split = Split({
      size = "50%",
      position = "left",
    })

    left_half_split:mount()

    split = Split({
      size = 20,
      position = "bottom",
      relative = "editor",
    })

    split:mount()

    eq(vim.api.nvim_win_get_width(split.winid), vim.o.columns)

    left_half_split:unmount()
  end)

  describe("method :mount", function()
    it("opens win if not mounted", function()
      split = Split({
        size = 20,
        position = "bottom",
      })

      local prev_winids = vim.api.nvim_list_wins()

      split:mount()

      local new_winids = vim.tbl_filter(function(winid)
        return not vim.tbl_contains(prev_winids, winid)
      end, vim.api.nvim_list_wins())

      eq(#new_winids, 1)
    end)

    it("does nothing if already mounted", function()
      split = Split({
        size = 20,
        position = "bottom",
      })

      split:mount()

      local prev_winids = vim.api.nvim_list_wins()

      split:mount()

      local new_winids = vim.tbl_filter(function(winid)
        return not vim.tbl_contains(prev_winids, winid)
      end, vim.api.nvim_list_wins())

      eq(#new_winids, 0)
    end)
  end)

  describe("method :unmount", function()
    it("closes win if mounted", function()
      split = Split({
        size = 20,
        position = "bottom",
      })

      split:mount()

      local split_winid = split.winid

      local prev_winids = vim.api.nvim_list_wins()

      split:unmount()

      local curr_winids = vim.api.nvim_list_wins()
      local closed_winids = vim.tbl_filter(function(winid)
        return not vim.tbl_contains(curr_winids, winid)
      end, prev_winids)

      eq(#closed_winids, 1)
      eq(closed_winids[1], split_winid)
    end)

    it("does nothing if already unmounted", function()
      split = Split({
        size = 20,
        position = "bottom",
      })

      local prev_winids = vim.api.nvim_list_wins()

      split:unmount()

      local curr_winids = vim.api.nvim_list_wins()
      local closed_winids = vim.tbl_filter(function(winid)
        return not vim.tbl_contains(curr_winids, winid)
      end, prev_winids)

      eq(#closed_winids, 0)
    end)
  end)

  describe("method :hide", function()
    it("works", function()
      local winid = vim.api.nvim_get_current_win()

      local win_height = vim.api.nvim_win_get_height(winid)

      split = Split({
        size = 20,
        position = "bottom",
      })

      split:mount()

      vim.api.nvim_buf_set_lines(split.bufnr, 0, -1, false, {
        "42",
      })

      eq(vim.api.nvim_win_get_height(winid) < win_height, true)

      split:hide()

      h.assert_buf_lines(split.bufnr, {
        "42",
      })

      eq(vim.api.nvim_win_get_height(winid) == win_height, true)
    end)

    it("is idempotent", function()
      split = Split({
        size = 20,
        position = "bottom",
      })

      split:mount()

      local prev_winids = vim.api.nvim_list_wins()

      split:hide()

      local curr_winids = vim.api.nvim_list_wins()

      eq(#prev_winids, #curr_winids + 1)

      split:hide()

      eq(#curr_winids, #vim.api.nvim_list_wins())
    end)

    it("does nothing if not mounted", function()
      split = Split({
        size = 20,
        position = "bottom",
      })

      local prev_winids = vim.api.nvim_list_wins()

      split:hide()

      local curr_winids = vim.api.nvim_list_wins()

      eq(#prev_winids, #curr_winids)
    end)
  end)

  describe("method :show", function()
    it("works", function()
      local winid = vim.api.nvim_get_current_win()

      split = Split({
        size = 20,
        position = "bottom",
      })

      split:mount()

      vim.api.nvim_buf_set_lines(split.bufnr, 0, -1, false, {
        "42",
      })

      local win_height = vim.api.nvim_win_get_height(winid)

      split:hide()
      split:show()

      h.assert_buf_lines(split.bufnr, {
        "42",
      })

      eq(vim.api.nvim_win_get_height(winid) == win_height, true)
    end)

    it("is idempotent", function()
      split = Split({
        size = 20,
        position = "bottom",
      })

      split:mount()

      split:hide()

      local prev_winids = vim.api.nvim_list_wins()

      split:show()

      local curr_winids = vim.api.nvim_list_wins()

      eq(#prev_winids + 1, #curr_winids)

      split:show()

      eq(#curr_winids, #vim.api.nvim_list_wins())
    end)

    it("does nothing if not mounted", function()
      split = Split({
        size = 20,
        position = "bottom",
      })

      local prev_winids = vim.api.nvim_list_wins()

      split:show()

      local curr_winids = vim.api.nvim_list_wins()

      eq(#prev_winids, #curr_winids)
    end)

    it("does nothing if not hidden", function()
      split = Split({
        size = 20,
        position = "bottom",
      })

      split:mount()

      local prev_winids = vim.api.nvim_list_wins()

      split:show()

      local curr_winids = vim.api.nvim_list_wins()

      eq(#prev_winids, #curr_winids)
    end)
  end)

  h.describe_flipping_feature("lua_keymap", "method :map", function()
    it("supports lhs table", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", { "k", "l" }, "o42<esc>")

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
        "42",
        "42",
      })
    end)

    it("supports rhs function", function()
      local callback = spy.new(function() end)

      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "l", function()
        callback()
      end)

      feedkeys("l", "x")

      assert.spy(callback).called()
    end)

    it("supports rhs string", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "l", "o42<esc>")

      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
        "42",
      })
    end)

    it("supports o.remap=true", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "k", "o42<Esc>")
      split:map("n", "l", "k", { remap = true })

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
        "42",
        "42",
      })
    end)

    it("supports o.remap=false", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "k", "o42<Esc>")
      split:map("n", "l", "k", { remap = false })

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
        "42",
      })
    end)

    it("throws if not mounted", function()
      split = Split({
        size = 20,
      })

      local ok, result = pcall(function()
        split:map("n", "k", "o42<Esc>")
      end)

      eq(ok, false)
      eq(type(result), "string")
    end)
  end)

  describe("method :unmap", function()
    it("supports lhs string", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "l", "o42<esc>")

      split:unmap("n", "l")

      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
      })
    end)

    it("supports lhs table", function()
      split = Split({
        size = 20,
      })

      split:mount()

      split:map("n", "k", "o42<esc>")
      split:map("n", "l", "o42<esc>")

      split:unmap("n", { "k", "l" })

      feedkeys("k", "x")
      feedkeys("l", "x")

      h.assert_buf_lines(split.bufnr, {
        "",
      })
    end)

    it("throws if not mounted", function()
      split = Split({
        size = 20,
      })

      local ok, result = pcall(function()
        split:unmap("n", "l")
      end)

      eq(ok, false)
      eq(type(result), "string")
    end)
  end)

  h.describe_flipping_feature("lua_autocmd", "method :on", function()
    it("works", function()
      local callback = spy.new(function() end)

      split = Split({
        size = 20,
      })

      split:mount()

      split:on(event.InsertEnter, function()
        callback()
      end)

      feedkeys("i", "x")
      feedkeys("<esc>", "x")

      assert.spy(callback).called()
    end)

    it("throws if not mounted", function()
      split = Split({
        size = 20,
      })

      local ok, result = pcall(function()
        split:on(event.InsertEnter, function() end)
      end)

      eq(ok, false)
      eq(type(result), "string")
    end)
  end)

  h.describe_flipping_feature("lua_autocmd", "method :off", function()
    it("works", function()
      local callback = spy.new(function() end)

      split = Split({
        size = 20,
      })

      split:mount()

      split:on(event.InsertEnter, function()
        callback()
      end)

      split:off(event.InsertEnter)

      feedkeys("i", "x")
      feedkeys("<esc>", "x")

      assert.spy(callback).not_called()
    end)

    it("throws if not mounted", function()
      split = Split({
        size = 20,
      })

      local ok, result = pcall(function()
        split:off()
      end)

      eq(ok, false)
      eq(type(result), "string")
    end)
  end)
end)
