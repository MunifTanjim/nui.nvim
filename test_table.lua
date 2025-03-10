for pkg_name in pairs(package.loaded) do
  if pkg_name:match("^nui") then
    package.loaded[pkg_name] = nil
  end
end

local Line = require("nui.line")
local Split = require("nui.split")
local Table = require("nui.table")
local Text = require("nui.text")

local split = Split({
  position = "bottom",
  size = 20,
})

---@type table<string, table<nui_table_border_char_name,string>>
local border_styles = {
  single = {
    down_hor = "┬",
    down_left = "┐",
    down_right = "┌",
    hor = "─",
    up_hor = "┴",
    up_left = "┘",
    up_right = "└",
    ver = "│",
    ver_hor = "┼",
    ver_left = "┤",
    ver_right = "├",
  },
  double = {
    down_hor = "╦",
    down_left = "╗",
    down_right = "╔",
    hor = "═",
    up_hor = "╩",
    up_left = "╝",
    up_right = "╚",
    ver = "║",
    ver_hor = "╬",
    ver_left = "╣",
    ver_right = "╠",
  },
}

local default_border = border_styles.single
-- local border = {
--   hor = "─",
--   ver = Text("│", "GruvboxPurple"),
--   down_right = "┌",
--   down_hor = "┬",
--   down_left = "┐",
--   ver_right = "├",
--   ver_hor = "┼",
--   ver_left = "┤",
--   up_right = "└",
--   up_hor = "┴",
--   up_left = "┘",
--   header = {
--     hor = "─",
--   },
--   footer = {
--     hor = "─",
--   },
-- }

local data = {
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

local basic_columns = {
  {
    accessor_key = "firstName",
    footer = function(info)
      return info.column.id
    end,
  },
  {
    id = "lastName",
    accessor_fn = function(row)
      return row.lastName
    end,
    footer = function(info)
      return info.column.id
    end,
  },
  {
    header = "Age",
    accessor_key = "age",
    cell = function(info)
      return Line({ Text(tostring(info.get_value()), "GruvboxBlue"), Text(" years", "GruvboxRed") })
    end,
    footer = function(info)
      return info.column.id
    end,
    min_width = 10,
    align = "right",
  },
  {
    header = "Visits",
    accessor_key = "visits",
    footer = function(info)
      return info.column.id
    end,
  },
  {
    header = "Status",
    accessor_key = "status",
    footer = function(info)
      return info.column.id
    end,
    max_width = 5,
  },
  {
    header = "Profile Progress",
    accessor_key = "progress",
    footer = function(info)
      return info.column.id
    end,
  },
}

local function cell_id(cell)
  return cell.column.id
end

local function capitalize(value)
  return (string.gsub(value, "^%l", string.upper))
end

local grouped_columns = {
  {
    align = "center",
    header = "Name",
    footer = cell_id,
    columns = {
      {
        accessor_key = "firstName",
        cell = function(cell)
          return Text(capitalize(cell.get_value()), "DiagnosticInfo")
        end,
        header = "First",
        footer = cell_id,
      },
      {
        id = "lastName",
        accessor_fn = function(row)
          return capitalize(row.lastName)
        end,
        header = "Last",
        footer = cell_id,
      },
    },
  },
  {
    align = "center",
    header = "Info",
    footer = cell_id,
    columns = {
      {
        align = "center",
        accessor_key = "age",
        cell = function(cell)
          return Line({ Text(tostring(cell.get_value()), "DiagnosticHint"), Text(" y/o") })
        end,
        header = "Age",
        footer = "age",
      },
      {
        align = "center",
        header = "More Info",
        footer = cell_id,
        columns = {
          {
            align = "right",
            accessor_key = "visits",
            header = "Visits",
            footer = cell_id,
          },
          {
            accessor_key = "status",
            header = "Status",
            footer = cell_id,
            max_width = 6,
          },
        },
      },
    },
  },
  {
    align = "right",
    header = "Progress",
    accessor_key = "progress",
    footer = cell_id,
  },
}

local table = Table({
  border = {
    down_hor = "╦",
    down_left = "╗",
    down_right = "╔",
    hor = "═",
    up_hor = "╩",
    up_left = "╝",
    up_right = "╚",
    ver = "║",
    ver_hor = "╬",
    ver_left = "╣",
    ver_right = "╠",
    d = {
      ver = " ",
      hor = " ",
    },
  },
  bufnr = split.bufnr,
  columns = grouped_columns,
  data = data,
})

vim.bo[split.bufnr].modifiable = true
vim.bo[split.bufnr].readonly = false
vim.api.nvim_buf_set_lines(split.bufnr, 0, -1, false, {
  "HELLO",
  "",
  "",
  "",
  "HOLA!",
})
vim.bo[split.bufnr].modifiable = false
vim.bo[split.bufnr].readonly = true

local linenr = 3

table:render(linenr)

split:mount()

split:map("n", "q", function()
  split:unmount()
end, {})

-- split:map("n", "J", function()
--   linenr = linenr + 1
--   table:render(linenr)
-- end, {})

-- split:map("n", "K", function()
--   linenr = linenr - 1
--   table:render(linenr)
-- end, {})
--
-- split:map("n", "x", function()
--   local cell = table:get_cell()
--   if cell then
--     print(vim.inspect(cell._range))
--     local column = cell.column
--     if column.accessor_key then
--       cell.row.original[column.accessor_key] = string.format("(%d)!", linenr)
--     end
--     table:refresh_cell(cell)
--   end
-- end, {})
