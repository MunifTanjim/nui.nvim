pcall(require, "luacov")

local Line = require("nui.line")
local Table = require("nui.table")
local Text = require("nui.text")
local h = require("tests.helpers")

local eq = h.eq

describe("nui.table", function()
  ---@type number, number
  local winid, bufnr

  before_each(function()
    winid = vim.api.nvim_get_current_win()
    bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_win_set_buf(winid, bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  describe("o.bufnr", function()
    it("throws if missing", function()
      local ok, err = pcall(Table, {})
      eq(ok, false)
      eq(type(string.match(err, "missing bufnr")), "string")
    end)

    it("throws if invalid", function()
      local ok, err = pcall(Table, { bufnr = 999 })
      eq(ok, false)
      eq(type(string.match(err, "invalid bufnr ")), "string")
    end)

    it("sets t.bufnr properly", function()
      local table = Table({ bufnr = bufnr })

      eq(table.bufnr, bufnr)
    end)
  end)

  describe("o.buf_options", function()
    it("sets default buf options emulating scratch-buffer", function()
      local table = Table({ bufnr = bufnr })

      h.assert_buf_options(table.bufnr, {
        bufhidden = "hide",
        buflisted = false,
        buftype = "nofile",
        swapfile = false,
      })
    end)

    it("locks buffer by default", function()
      local table = Table({ bufnr = bufnr })

      h.assert_buf_options(table.bufnr, {
        modifiable = false,
        readonly = true,
        undolevels = 0,
      })
    end)

    it("sets values", function()
      local table = Table({
        bufnr = bufnr,
        buf_options = {
          undolevels = -1,
        },
      })

      h.assert_buf_options(table.bufnr, {
        undolevels = -1,
      })
    end)
  end)

  describe("o.ns_id", function()
    it("sets t.ns_id if o.ns_id is string", function()
      local ns = "NuiTest"
      local table = Table({ bufnr = bufnr, ns_id = ns })

      local namespaces = vim.api.nvim_get_namespaces()

      eq(table.ns_id, namespaces[ns])
    end)

    it("sets t.ns_id if o.ns_id is number", function()
      local ns = "NuiTest"
      local ns_id = vim.api.nvim_create_namespace(ns)
      local table = Table({ bufnr = bufnr, ns_id = ns_id })

      eq(table.ns_id, ns_id)
    end)
  end)

  describe("o.columns", function()
    describe(".id", function()
      it("fallbacks t o .accessor_key", function()
        local table = Table({
          bufnr = bufnr,
          columns = { { accessor_key = "ID" } },
          data = { { ID = 42 } },
        })

        table:render()

        vim.api.nvim_win_set_cursor(winid, { 2, 3 })

        eq(table:get_cell().column.id, "ID")
      end)

      for header_type, header in pairs({
        string = "ID",
        NuiText = Text("ID"),
        NuiLine = Line({ Text("I"), Text("D") }),
      }) do
        it(string.format("fallbacks to .header (%s)", header_type), function()
          local table = Table({
            bufnr = bufnr,
            columns = {
              {
                header = header,
                accessor_fn = function()
                  return ""
                end,
              },
            },
            data = { {} },
          })

          table:render()

          vim.api.nvim_win_set_cursor(winid, { 4, 3 })

          eq(table:get_cell().column.id, "ID")
        end)
      end

      it("throws if missing", function()
        local ok, err = pcall(function()
          return Table({
            bufnr = bufnr,
            columns = { {} },
          })
        end)
        eq(ok, false)
        eq(type(string.match(err, "missing column id")), "string")
      end)
    end)
  end)

  describe("method :render", function()
    local columns
    local data

    before_each(function()
      columns = {
        {
          header = "First Name",
          accessor_key = "firstName",
          footer = "firstName",
        },
        {
          header = "Last Name",
          accessor_key = "lastName",
          footer = "lastName",
        },
      }

      data = {
        {
          firstName = "tanner",
          lastName = "linsley",
          age = 24,
          visits = 100,
          status = "In Relationship",
          progress = 50,
        },
        {
          firstName = "tandy",
          lastName = "miller",
          age = 40,
          visits = 40,
          status = "Single",
          progress = 80,
        },
        {
          firstName = "joe",
          lastName = "dirte",
          age = 45,
          visits = 20,
          status = "Complicated",
          progress = 10,
        },
      }
    end)

    it("can handle empty columns", function()
      local table = Table({
        bufnr = bufnr,
        data = data,
      })
      table:render()
      h.assert_buf_lines(table.bufnr, { "" })
    end)

    it("can handle empty data", function()
      local table = Table({
        bufnr = bufnr,
        columns = {
          {
            accessor_key = "firstName",
          },
        },
      })
      table:render()
      h.assert_buf_lines(table.bufnr, { "" })
    end)

    it("can handle empty columns and data", function()
      local table = Table({ bufnr = bufnr })
      table:render()
      h.assert_buf_lines(table.bufnr, { "" })
    end)

    it("works w/ header w/ footer", function()
      local table = Table({
        bufnr = bufnr,
        columns = columns,
        data = data,
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌──────────┬─────────┐",
        "│First Name│Last Name│",
        "├──────────┼─────────┤",
        "│tanner    │linsley  │",
        "├──────────┼─────────┤",
        "│tandy     │miller   │",
        "├──────────┼─────────┤",
        "│joe       │dirte    │",
        "├──────────┼─────────┤",
        "│firstName │lastName │",
        "└──────────┴─────────┘",
      })
    end)

    it("works w/ header w/o footer", function()
      for _, column in ipairs(columns) do
        column.align = "center"
        column.footer = nil
      end

      local table = Table({
        bufnr = bufnr,
        columns = columns,
        data = data,
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌──────────┬─────────┐",
        "│First Name│Last Name│",
        "├──────────┼─────────┤",
        "│  tanner  │ linsley │",
        "├──────────┼─────────┤",
        "│  tandy   │ miller  │",
        "├──────────┼─────────┤",
        "│   joe    │  dirte  │",
        "└──────────┴─────────┘",
      })
    end)

    it("works w/o header w/ footer", function()
      for _, column in ipairs(columns) do
        column.header = nil
      end

      local table = Table({
        bufnr = bufnr,
        columns = columns,
        data = data,
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌─────────┬────────┐",
        "│tanner   │linsley │",
        "├─────────┼────────┤",
        "│tandy    │miller  │",
        "├─────────┼────────┤",
        "│joe      │dirte   │",
        "├─────────┼────────┤",
        "│firstName│lastName│",
        "└─────────┴────────┘",
      })
    end)

    it("works w/o header w/o footer", function()
      for _, column in ipairs(columns) do
        column.header = nil
        column.footer = nil
      end

      local table = Table({
        bufnr = bufnr,
        columns = columns,
        data = data,
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌──────┬───────┐",
        "│tanner│linsley│",
        "├──────┼───────┤",
        "│tandy │miller │",
        "├──────┼───────┤",
        "│joe   │dirte  │",
        "└──────┴───────┘",
      })
    end)

    it("supports param linenr_start", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "START: NuiTest",
        "",
        "END: NuiTest",
      })

      local table = Table({
        bufnr = bufnr,
        columns = columns,
        data = { data[1] },
      })

      table:render(2)
      h.assert_buf_lines(table.bufnr, {
        "START: NuiTest",
        "┌──────────┬─────────┐",
        "│First Name│Last Name│",
        "├──────────┼─────────┤",
        "│tanner    │linsley  │",
        "├──────────┼─────────┤",
        "│firstName │lastName │",
        "└──────────┴─────────┘",
        "END: NuiTest",
      })

      table:render(4)
      h.assert_buf_lines(table.bufnr, {
        "START: NuiTest",
        "",
        "",
        "┌──────────┬─────────┐",
        "│First Name│Last Name│",
        "├──────────┼─────────┤",
        "│tanner    │linsley  │",
        "├──────────┼─────────┤",
        "│firstName │lastName │",
        "└──────────┴─────────┘",
        "END: NuiTest",
      })

      table:render(3)
      h.assert_buf_lines(table.bufnr, {
        "START: NuiTest",
        "",
        "┌──────────┬─────────┐",
        "│First Name│Last Name│",
        "├──────────┼─────────┤",
        "│tanner    │linsley  │",
        "├──────────┼─────────┤",
        "│firstName │lastName │",
        "└──────────┴─────────┘",
        "END: NuiTest",
      })
    end)

    describe("grouped columns", function()
      local grouped_columns
      before_each(function()
        grouped_columns = {
          {
            header = "Name",
            footer = function(info)
              return info.column.id
            end,
            columns = {
              {
                accessor_key = "firstName",
                footer = "firstName",
              },
              {
                id = "lastName",
                header = "Last Name",
                accessor_key = "lastName",
                footer = function(info)
                  return info.column.id
                end,
              },
            },
          },
          {
            header = "Info",
            footer = function(info)
              return info.column.id
            end,
            columns = {
              {
                header = "Age",
                accessor_key = "age",
                footer = "age",
              },
              {
                header = "More Info",
                footer = function(info)
                  return info.column.id
                end,
                columns = {
                  {
                    accessor_key = "visits",
                    header = "Visits",
                    footer = function(info)
                      return info.column.id
                    end,
                  },
                  {
                    accessor_key = "status",
                    header = "Status",
                    footer = function(info)
                      return info.column.id
                    end,
                  },
                },
              },
            },
          },
          {
            header = "Profile Progress",
            accessor_key = "progress",
            footer = function(info)
              return info.column.id
            end,
          },
        }
      end)

      it("is drawn correctly", function()
        local table = Table({
          bufnr = bufnr,
          columns = grouped_columns,
          data = data,
        })

        table:render()

        h.assert_buf_lines(table.bufnr, {
          "┌───────────────────┬──────────────────────────┬────────────────┐",
          "│Name               │Info                      │                │",
          "├─────────┬─────────┼───┬──────────────────────┤                │",
          "│         │         │   │More Info             │                │",
          "│         │         │   ├──────┬───────────────┤                │",
          "│firstName│Last Name│Age│Visits│Status         │Profile Progress│",
          "├─────────┼─────────┼───┼──────┼───────────────┼────────────────┤",
          "│tanner   │linsley  │24 │100   │In Relationship│50              │",
          "├─────────┼─────────┼───┼──────┼───────────────┼────────────────┤",
          "│tandy    │miller   │40 │40    │Single         │80              │",
          "├─────────┼─────────┼───┼──────┼───────────────┼────────────────┤",
          "│joe      │dirte    │45 │20    │Complicated    │10              │",
          "├─────────┼─────────┼───┼──────┼───────────────┼────────────────┤",
          "│firstName│lastName │age│visits│status         │progress        │",
          "│         │         │   ├──────┴───────────────┤                │",
          "│         │         │   │More Info             │                │",
          "├─────────┴─────────┼───┴──────────────────────┤                │",
          "│Name               │Info                      │                │",
          "└───────────────────┴──────────────────────────┴────────────────┘",
        })
      end)
    end)
  end)

  describe("method :get_cell", function()
    it("returns nil on border", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value" } },
        data = { { value = "Such Value!" } },
      })

      table:render()

      vim.api.nvim_win_set_cursor(winid, { 1, 5 })

      local cell = table:get_cell()

      eq(cell, nil)
    end)

    it("works after shifting", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value" } },
        data = { { id = 0, value = "Such Value!" } },
      })

      table:render()

      local cell

      vim.api.nvim_win_set_cursor(winid, { 2, 5 })
      cell = table:get_cell()
      eq(type(cell), "table")
      eq(cell.row.original.id, 0)

      table:render(2)

      vim.api.nvim_win_set_cursor(winid, { 2, 5 })
      cell = table:get_cell()
      eq(type(cell), "nil")

      vim.api.nvim_win_set_cursor(winid, { 3, 5 })
      cell = table:get_cell()
      eq(type(cell), "table")
      eq(cell.row.original.id, 0)
    end)

    it("can take position", function()
      local table = Table({
        bufnr = bufnr,
        columns = {
          { accessor_key = "id" },
          { accessor_key = "value" },
        },
        data = {
          { id = 1, value = "One" },
          { id = 2, value = "Two" },
        },
      })

      table:render()

      local cell

      vim.api.nvim_win_set_cursor(winid, { 2, 3 })
      cell = table:get_cell()
      eq(cell.get_value(), 1)

      cell = table:get_cell({ 1, 1 })
      eq(cell.get_value(), "Two")
    end)
  end)

  describe("method :refresh_cell", function()
    it("can truncate NuiText on refesh", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value" } },
        data = { { value = "Such Value!" } },
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌───────────┐",
        "│Such Value!│",
        "└───────────┘",
      })

      vim.api.nvim_win_set_cursor(winid, { 2, 5 })

      local cell = table:get_cell()

      cell.row.original.value = "Such Looooooog Value!"

      table:refresh_cell(cell)

      h.assert_buf_lines(table.bufnr, {
        "┌───────────┐",
        "│Such Loooo…│",
        "└───────────┘",
      })
    end)

    it("can truncate NuiLine on refesh", function()
      local table = Table({
        bufnr = bufnr,
        columns = {
          {
            accessor_key = "value",
            cell = function(cell)
              return Line({ Text(tostring(cell.get_value()), "NuiTest"), Text(" years old") })
            end,
          },
        },
        data = { { value = 42 } },
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌────────────┐",
        "│42 years old│",
        "└────────────┘",
      })

      vim.api.nvim_win_set_cursor(winid, { 2, 5 })

      local cell = table:get_cell()

      eq(type(cell), "table")

      cell.row.original.value = 100

      table:refresh_cell(cell)

      h.assert_buf_lines(table.bufnr, {
        "┌────────────┐",
        "│100 years o…│",
        "└────────────┘",
      })
    end)
  end)
end)
