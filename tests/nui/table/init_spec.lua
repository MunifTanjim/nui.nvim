pcall(require, "luacov")

local Line = require("nui.line")
local Table = require("nui.table")
local Text = require("nui.text")
local h = require("tests.helpers")

local eq = h.eq

local function id_value_columns()
  return {
    { accessor_key = "id" },
    { accessor_key = "value" },
  }
end

local function sample_data()
  return {
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
end

local function grouped_columns_fixture()
  return {
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
end

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

      data = sample_data()
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
      it("is drawn correctly", function()
        local table = Table({
          bufnr = bufnr,
          columns = grouped_columns_fixture(),
          data = sample_data(),
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

    describe("borderless (border = 'none')", function()
      it("draws no border lines, separating columns with a space", function()
        local table = Table({
          bufnr = bufnr,
          border = "none",
          columns = id_value_columns(),
          data = {
            { id = 1, value = "One" },
            { id = 2, value = "Two" },
          },
        })

        table:render()

        h.assert_buf_lines(table.bufnr, {
          " 1 One ",
          " 2 Two ",
        })
      end)

      it("works w/ header w/ footer", function()
        local table = Table({
          bufnr = bufnr,
          border = "none",
          columns = { { accessor_key = "value", header = "Val", footer = "Val" } },
          data = { { value = "one" } },
        })

        table:render()

        h.assert_buf_lines(table.bufnr, {
          " Val ",
          " one ",
          " Val ",
        })
      end)

      it("maps consecutive rows onto consecutive lines", function()
        local table = Table({
          bufnr = bufnr,
          border = "none",
          columns = id_value_columns(),
          data = {
            { id = 1, value = "One" },
            { id = 2, value = "Two" },
            { id = 3, value = "Three" },
          },
        })

        table:render()

        -- rows sit on consecutive lines, no separator line in between
        h.assert_buf_lines(table.bufnr, {
          " 1 One   ",
          " 2 Two   ",
          " 3 Three ",
        })
      end)

      it("renders grouped columns", function()
        local table = Table({
          bufnr = bufnr,
          border = "none",
          columns = {
            {
              header = "Name",
              columns = {
                { accessor_key = "first", header = "First" },
                { accessor_key = "last", header = "Last" },
              },
            },
            { accessor_key = "age", header = "Age" },
          },
          data = { { first = "a", last = "bb", age = 1 } },
        })

        table:render()

        -- no border chars, no horizontal rules; the group header spans its
        -- leaf columns and every line is padded to the full table width.
        h.assert_buf_lines(table.bufnr, {
          " Name           ",
          " First Last Age ",
          " a     bb   1   ",
        })
        eq(table:get_size(), { width = 16, height = 3 })
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

    it("biases right when the cursor is on an internal vertical border", function()
      local table = Table({
        bufnr = bufnr,
        columns = id_value_columns(),
        data = { { id = 1, value = "One" } },
      })

      table:render()

      -- ┌─┬───┐
      -- │1│One│   <- line 2; the internal `│` between the cells is at byte col 4
      -- └─┴───┘
      vim.api.nvim_win_set_cursor(winid, { 2, 4 })

      -- the cursor isn't on any cell content, so get_cell biases to the right
      local cell = table:get_cell()
      eq(cell.column.id, "value")
      eq(cell.get_value(), "One")
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
        columns = id_value_columns(),
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

    describe("grouped columns", function()
      it("resolves header and footer cells", function()
        local table = Table({
          bufnr = bufnr,
          columns = grouped_columns_fixture(),
          data = sample_data(),
        })

        table:render()

        local function at(line, col)
          vim.api.nvim_win_set_cursor(winid, { line, col })
          return table:get_cell()
        end

        -- header group row (line 2): top-level groups
        local cell = at(2, 3) -- "Name" group
        eq(cell.type, "header")
        eq(cell.column.id, "Name")

        cell = at(2, 25) -- "Info" group
        eq(cell.type, "header")
        eq(cell.column.id, "Info")

        -- a spanned-empty group area still resolves to its group cell:
        -- on line 2, the rightmost region belongs to "Profile Progress"
        cell = at(2, 55)
        eq(cell.type, "header")
        eq(cell.column.id, "progress")

        -- leaf header row (line 6)
        cell = at(6, 3) -- firstName
        eq(cell.type, "header")
        eq(cell.column.id, "firstName")

        cell = at(6, 27) -- Age
        eq(cell.type, "header")
        eq(cell.column.id, "age")

        -- footer leaf row (line 14)
        cell = at(14, 3)
        eq(cell.type, "footer")
        eq(cell.column.id, "firstName")

        -- footer group row (line 18)
        cell = at(18, 3)
        eq(cell.type, "footer")
        eq(cell.column.id, "Name")

        -- data cells still resolve as type "data" (line 8)
        cell = at(8, 3)
        eq(cell.type, "data")
        eq(cell.get_value(), "tanner")

        -- a border line resolves to nothing
        eq(at(1, 4), nil)
      end)
    end)

    describe("borderless (border = 'none')", function()
      it("maps each consecutive line to the correct row", function()
        local table = Table({
          bufnr = bufnr,
          border = "none",
          columns = id_value_columns(),
          data = {
            { id = 1, value = "One" },
            { id = 2, value = "Two" },
            { id = 3, value = "Three" },
          },
        })

        table:render()

        -- consecutive rows share no separator line, so each buffer line maps
        -- directly to the row at the same index
        vim.api.nvim_win_set_cursor(winid, { 1, 1 })
        eq(table:get_cell().get_value(), 1)
        vim.api.nvim_win_set_cursor(winid, { 2, 1 })
        eq(table:get_cell().get_value(), 2)
        vim.api.nvim_win_set_cursor(winid, { 3, 1 })
        eq(table:get_cell().get_value(), 3)
      end)
    end)
  end)

  describe("method :goto_cell", function()
    describe("flat columns", function()
      local table

      before_each(function()
        table = Table({
          bufnr = bufnr,
          columns = id_value_columns(),
          data = {
            { id = 1, value = "One" },
            { id = 2, value = "Two" },
          },
        })

        table:render()

        -- ┌─┬───┐   line 1
        -- │1│One│   line 2
        -- ├─┼───┤   line 3
        -- │2│Two│   line 4
        -- └─┴───┘   line 5
        --
        -- `│` is 3 bytes wide, so (0-indexed) byte cols are:
        --   id cell content    -> col 3
        --   value cell content -> col 7

        -- start on row 1, id cell
        vim.api.nvim_win_set_cursor(winid, { 2, 3 })
      end)

      it("moves over borders to the next/prev column and row", function()
        local cell

        cell = table:goto_cell({ 0, 1 }) -- right -> row 1, value
        eq(cell.get_value(), "One")
        eq(vim.api.nvim_win_get_cursor(winid), { 2, 7 })

        cell = table:goto_cell({ 1, 0 }) -- down -> row 2, value
        eq(cell.get_value(), "Two")
        eq(vim.api.nvim_win_get_cursor(winid), { 4, 7 })

        cell = table:goto_cell({ 0, -1 }) -- left -> row 2, id
        eq(cell.get_value(), 2)
        eq(vim.api.nvim_win_get_cursor(winid), { 4, 3 })

        cell = table:goto_cell({ -1, 0 }) -- up -> row 1, id
        eq(cell.get_value(), 1)
        eq(vim.api.nvim_win_get_cursor(winid), { 2, 3 })
      end)

      it("is a no-op at the table edges", function()
        -- at row 1, id cell: no cell above or to the left
        eq(table:goto_cell({ -1, 0 }), nil)
        eq(vim.api.nvim_win_get_cursor(winid), { 2, 3 })

        eq(table:goto_cell({ 0, -1 }), nil)
        eq(vim.api.nvim_win_get_cursor(winid), { 2, 3 })
      end)

      it("snaps to the current cell content when given no position", function()
        -- cursor sits on the id cell content already; snapping keeps it there
        vim.api.nvim_win_set_cursor(winid, { 4, 7 })

        local cell = table:goto_cell()
        eq(cell.get_value(), "Two")
        eq(vim.api.nvim_win_get_cursor(winid), { 4, 7 })
      end)
    end)

    describe("grouped columns", function()
      it("navigates the leaf columns", function()
        local table = Table({
          bufnr = bufnr,
          columns = grouped_columns_fixture(),
          data = sample_data(),
        })

        table:render()

        -- per the layout above, row 1 (tanner) content is on line 8,
        -- with "tanner" starting at byte col 3 (after the 3-byte `│`).
        vim.api.nvim_win_set_cursor(winid, { 8, 3 })

        local function at(cell, row_index, column_id, value)
          eq(cell.row.index, row_index)
          eq(cell.column.id, column_id)
          eq(cell.get_value(), value)
          -- cursor actually landed on this cell: re-resolving finds the same one
          eq(table:get_cell().column.id, column_id)
          eq(table:get_cell().row.index, row_index)
        end

        at(table:get_cell(), 1, "firstName", "tanner")

        -- walk right across every leaf column, skipping the grouping borders
        at(table:goto_cell({ 0, 1 }), 1, "lastName", "linsley")
        at(table:goto_cell({ 0, 1 }), 1, "age", 24)
        at(table:goto_cell({ 0, 1 }), 1, "visits", 100)
        at(table:goto_cell({ 0, 1 }), 1, "status", "In Relationship")
        at(table:goto_cell({ 0, 1 }), 1, "progress", 50)

        -- right of the last leaf column is a no-op
        eq(table:goto_cell({ 0, 1 }), nil)

        -- vertical + horizontal moves resolve to the right leaf cells
        at(table:goto_cell({ 1, 0 }), 2, "progress", 80)
        at(table:goto_cell({ 0, -1 }), 2, "status", "Single")
        at(table:goto_cell({ -1, 0 }), 1, "status", "In Relationship")
      end)

      it("navigates continuously across header, data, and footer", function()
        local table = Table({
          bufnr = bufnr,
          columns = grouped_columns_fixture(),
          data = sample_data(),
        })

        table:render()

        -- start on the Status data cell of row 1 (line 8); byte 42 is the "I"
        -- of "In Relationship" (the Status column's content).
        vim.api.nvim_win_set_cursor(winid, { 8, 42 })
        local cell = table:get_cell()
        eq(cell.type, "data")
        eq(cell.column.id, "status")
        eq(cell.get_value(), "In Relationship")

        -- up from data into the header stack, following the Status column
        eq(table:goto_cell({ -1, 0 }).column.id, "status") -- leaf header
        eq(table:goto_cell({ -1, 0 }).column.id, "More Info") -- group
        cell = table:goto_cell({ -1, 0 })
        eq(cell.type, "header")
        eq(cell.column.id, "Info") -- top-level group

        -- top edge is a no-op
        eq(table:goto_cell({ -1, 0 }), nil)

        -- coming back down returns to the SAME leaf column (cursor-x carries it)
        eq(table:goto_cell({ 1, 0 }).column.id, "More Info")
        eq(table:goto_cell({ 1, 0 }).column.id, "status")
        cell = table:goto_cell({ 1, 0 })
        eq(cell.type, "data")
        eq(cell.column.id, "status")
        eq(cell.get_value(), "In Relationship")

        -- continue down through the data rows into the footer
        eq(table:goto_cell({ 1, 0 }).get_value(), "Single") -- row 2
        eq(table:goto_cell({ 1, 0 }).get_value(), "Complicated") -- row 3
        cell = table:goto_cell({ 1, 0 }) -- into the footer
        eq(cell.type, "footer")
        eq(cell.column.id, "status")

        -- horizontal stepping within a header (group) row
        vim.api.nvim_win_set_cursor(winid, { 2, 3 }) -- "Name" group
        eq(table:get_cell().column.id, "Name")
        eq(table:goto_cell({ 0, 1 }).column.id, "Info")
        eq(table:goto_cell({ 0, 1 }).column.id, "progress") -- Profile Progress
        eq(table:goto_cell({ 0, 1 }), nil) -- right edge is a no-op
      end)

      it("biases right when a vertical move lands on a border", function()
        local table = Table({
          bufnr = bufnr,
          columns = grouped_columns_fixture(),
          data = sample_data(),
        })

        table:render()

        -- line 4 is the "More Info" header row; byte 39 is char col 32, which
        -- sits inside More Info's content but lines up exactly with the
        -- Visits│Status border on the leaf header row (line 6).
        vim.api.nvim_win_set_cursor(winid, { 4, 39 })
        eq(table:get_cell().column.id, "More Info")

        -- moving down keeps that x; on line 6 it's a border, so it biases right
        -- to Status (it would be Visits if it biased left)
        local cell = table:goto_cell({ 1, 0 })
        eq(cell.type, "header")
        eq(cell.column.id, "status")
      end)
    end)

    describe("borderless (border = 'none')", function()
      it("navigates row and column moves", function()
        local table = Table({
          bufnr = bufnr,
          border = "none",
          columns = id_value_columns(),
          data = {
            { id = 1, value = "One" },
            { id = 2, value = "Two" },
          },
        })

        table:render()

        vim.api.nvim_win_set_cursor(winid, { 1, 1 }) -- on "1"
        eq(table:get_cell().get_value(), 1)

        local cell = table:goto_cell({ 0, 1 }) -- right -> value
        eq(cell.get_value(), "One")
        eq(vim.api.nvim_win_get_cursor(winid), { 1, 3 })

        cell = table:goto_cell({ 1, 0 }) -- down -> row 2 value
        eq(cell.get_value(), "Two")
        eq(vim.api.nvim_win_get_cursor(winid), { 2, 3 })
      end)

      it("navigates grouped columns", function()
        local table = Table({
          bufnr = bufnr,
          border = "none",
          columns = {
            {
              header = "Name",
              columns = {
                { accessor_key = "first", header = "First" },
                { accessor_key = "last", header = "Last" },
              },
            },
            { accessor_key = "age", header = "Age" },
          },
          data = { { first = "a", last = "bb", age = 1 } },
        })

        table:render()

        -- data cell resolves, then walks up into the leaf and group headers,
        -- proving the recomputed group widths line up across the grid.
        vim.api.nvim_win_set_cursor(winid, { 3, 1 }) -- on "a"
        eq(table:get_cell().column.id, "first")

        local cell = table:goto_cell({ -1, 0 }) -- up -> leaf header
        eq(cell.type, "header")
        eq(cell.column.id, "first")

        cell = table:goto_cell({ -1, 0 }) -- up -> group header
        eq(cell.type, "header")
        eq(cell.column.id, "Name")

        -- horizontal step within the group-header row reaches the Age group
        eq(table:goto_cell({ 0, 1 }).column.id, "age")
      end)
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

    describe("borderless (border = 'none')", function()
      it("refreshes the correct row when rows share no separator", function()
        local table = Table({
          bufnr = bufnr,
          border = "none",
          columns = id_value_columns(),
          data = {
            { id = 1, value = "One" },
            { id = 2, value = "Two" },
            { id = 3, value = "Three" },
          },
        })

        table:render()

        -- refreshing a non-first row edits only that line, even though the
        -- borderless rows sit on consecutive lines with no separator
        vim.api.nvim_win_set_cursor(winid, { 3, 4 })
        local cell = table:get_cell()
        eq(cell.get_value(), "Three")

        cell.row.original.value = "XXX"
        table:refresh_cell(cell)

        h.assert_buf_lines(table.bufnr, {
          " 1 One   ",
          " 2 Two   ",
          " 3 XXX   ",
        })
      end)
    end)
  end)

  describe("method :set_data", function()
    it("replaces data on next render", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value" } },
        data = { { value = "one" } },
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌───┐",
        "│one│",
        "└───┘",
      })

      table:set_data({ { value = "two" }, { value = "three" } })
      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌─────┐",
        "│two  │",
        "├─────┤",
        "│three│",
        "└─────┘",
      })
    end)

    it("returns self for chaining", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value" } },
        data = {},
      })

      eq(table:set_data({ { value = "x" } }), table)
    end)

    it("shrinks column width when new data is narrower", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value" } },
        data = { { value = "loooooong" } },
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌─────────┐",
        "│loooooong│",
        "└─────────┘",
      })

      table:set_data({ { value = "hi" } })
      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌──┐",
        "│hi│",
        "└──┘",
      })
    end)

    it("keeps a configured width fixed, truncating wider content", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value", width = 6 } },
        data = { { value = "abcdefgh" } },
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌──────┐",
        "│abcde…│",
        "└──────┘",
      })

      table:set_data({ { value = "hi" } })
      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌──────┐",
        "│hi    │",
        "└──────┘",
      })
    end)

    describe("borderless (border = 'none')", function()
      it("recomputes width on set_data", function()
        local table = Table({
          bufnr = bufnr,
          border = "none",
          columns = { { accessor_key = "value" } },
          data = { { value = "one" } },
        })

        table:render()
        h.assert_buf_lines(table.bufnr, { " one " })

        table:set_data({ { value = "loooong" } })
        table:render()
        h.assert_buf_lines(table.bufnr, { " loooong " })
      end)
    end)
  end)

  describe("column width", function()
    it("flexes to content when no width is configured", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value" } },
        data = { { value = "hi" }, { value = "loooooong" } },
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌─────────┐",
        "│hi       │",
        "├─────────┤",
        "│loooooong│",
        "└─────────┘",
      })
    end)

    it("respects min_width when flexing", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value", min_width = 6 } },
        data = { { value = "hi" } },
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌──────┐",
        "│hi    │",
        "└──────┘",
      })
    end)

    it("respects max_width when flexing, truncating wider content", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value", max_width = 6 } },
        data = { { value = "abcdefgh" } },
      })

      table:render()

      h.assert_buf_lines(table.bufnr, {
        "┌──────┐",
        "│abcde…│",
        "└──────┘",
      })
    end)
  end)

  describe("method :get_size", function()
    it("returns nil before first render", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value" } },
        data = { { value = "one" } },
      })

      eq(table:get_size(), nil)
    end)

    it("returns dimensions of the last render", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value" } },
        data = { { value = "one" }, { value = "two" } },
      })

      table:render()

      eq(table:get_size(), { width = 5, height = 5 })
    end)

    it("updates after :set_data + :render", function()
      local table = Table({
        bufnr = bufnr,
        columns = { { accessor_key = "value" } },
        data = { { value = "one" } },
      })

      table:render()
      eq(table:get_size(), { width = 5, height = 3 })

      table:set_data({ { value = "loooooong" } })
      table:render()
      eq(table:get_size(), { width = 11, height = 3 })
    end)

    describe("borderless (border = 'none')", function()
      it("reports size of the borderless layout", function()
        local table = Table({
          bufnr = bufnr,
          border = "none",
          columns = id_value_columns(),
          data = {
            { id = 1, value = "One" },
            { id = 2, value = "Two" },
          },
        })

        table:render()

        eq(table:get_size(), { width = 7, height = 2 })
      end)
    end)
  end)
end)
