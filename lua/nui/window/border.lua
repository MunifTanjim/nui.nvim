local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type

local index_name = {
  "top_left",
  "top",
  "top_right",
  "right",
  "bottom_right",
  "bottom",
  "bottom_left",
  "left",
}

local function to_border_map(border)
  if not is_type("list", border) then
    error("invalid data")
  end

  -- fillup all 8 characters
  local count = vim.tbl_count(border)
  if count < 8 then
    for i = count + 1, 8 do
      local fallback_index = i % count
      border[i] = border[fallback_index == 0 and count or fallback_index]
    end
  end

  local named_border = {}

  for index, name in ipairs(index_name) do
    named_border[name] = border[index]
  end

  return named_border
end

local function to_border_list(named_border)
  if not is_type("map", named_border) then
    error("invalid data")
  end

  local border = {}

  for index, name in ipairs(index_name) do
    if is_type(named_border[name], "nil") then
      error(string.format("missing named border: %s", name))
    end

    border[index] = named_border[name]
  end

  return border
end

local function parse_border_text(text)
  local o = {
    count = {
      top = 0,
      bottom = 0,
    },
  }

  for position, text in pairs(defaults(text, {})) do
    local pos = string.sub(position, 1, 1)
    if pos == "t" then
      o.count.top = o.count.top + 1
      o[position] = text
    elseif pos == "b" then
      o.count.bottom = o.count.bottom + 1
      o[position] = text
    end
  end

  return o
end

local styles = {
  double  = to_border_map({ "╔", "═", "╗", "║", "╝", "═", "╚", "║" }),
  none    = "none",
  rounded = to_border_map({ "╭", "─", "╮", "│", "╯", "─", "╰", "│" }),
  shadow  = "shadow",
  single  = to_border_map({ "┌", "─", "┐", "│", "┘", "─", "└", "│" }),
  solid   = to_border_map({ "▛", "▀", "▜", "▐", "▟", "▄", "▙", "▌" }),
}

local Border = {}

function Border:new(window, definition)
  if is_type("string", definition) then
    definition = {
      style = definition
    }
  end

  local border = {
    window = window,
    type = "simple",
    style = defaults(definition.style, "rounded"),
    highlight = defaults(definition.highlight, "FloatBorder")
  }

  setmetatable(border, self)
  self.__index = self

  local style = border.style

  if is_type("list", style) then
    border.map = to_border_map(style)
  elseif is_type("string", style) then
    if not styles[style] then
      error("invalid border style name")
    end

    border.map = styles[style]
  end

  if is_type("string", border.map) then
    return border
  end

  border.text = parse_border_text(definition.text)

  if (border.text.count.top + border.text.count.bottom) > 0 then
    border.type = "complex"
  end

  if border.type == "complex" then
    border.size = vim.deepcopy(border.window.size)
    border.position = vim.deepcopy(border.window.position)

    if border.text.count.top > 0 or border.map.top ~= "" then
      border.size.height = border.size.height + 1
      border.window.position.row = border.window.position.row + 1
    end

    if border.text.count.bottom > 0 or border.map.bottom ~= "" then
      border.size.height = border.size.height + 1
    end

    if border.map.left ~= "" then
      border.size.width = border.size.width + 1
      border.window.position.col = border.window.position.col + 1
    end

    if border.map.right ~= "" then
      border.size.width = border.size.width + 1
    end
  end

  return border
end

function Border:draw()
  if self.type == "simple" then
    return
  end

  local size = self.size
  local position = self.position
  local text = self.text

  local edge_line = {
    top = "",
    bottom = "",
  }

  local parts = {
    top = {
      top_left = "",
      top = "",
      top_right = "",
    },
    bottom = {
      bottom_left = "",
      bottom = "",
      bottom_right = "",
    },
  }

  for edge in pairs(parts) do
    if text.count[edge] > 0 then
      local width = size.width - 2
      local max_length = math.floor(((size.width - 2 - text.count[edge] + 1) / text.count[edge]))

      for position in pairs(parts[edge]) do
        if text[position] then
          if #text[position] > max_length then
            parts[edge][position] = string.sub(text[position], 1, max_length - 1) .. "…"
          else
            parts[edge][position] = text[position]
          end
        end
      end

      local gap_length = (
        width - vim.fn.strchars(
          parts[edge][edge .. "_left"] .. parts[edge][edge] .. parts[edge][edge .. "_right"], tru
        )
      ) / 2

      edge_line[edge] = string.format(
        "%s%s%s%s%s",
        parts[edge][edge .. "_left"],
        string.rep(self.map.top, math.floor(gap_length)),
        parts[edge][edge],
        string.rep(self.map.top, math.ceil(gap_length)),
        parts[edge][edge .. "_right"]
      )
    else
      edge_line[edge] = string.rep(self.map[edge], size.width - 2)
    end
  end

  local middle_line = string.format("%s%s%s", self.map.left, string.rep(" ", size.width - 2), self.map.right)

  local lines = {}

  table.insert(lines, string.format("%s%s%s", self.map.top_left, edge_line.top, self.map.top_right))
  for _ = 1, size.height - 2 do
    table.insert(lines, middle_line)
  end
  table.insert(lines, string.format("%s%s%s", self.map.bottom_left, edge_line.bottom, self.map.bottom_right))

  self.bufnr = vim.api.nvim_create_buf(false, true)
  assert(self.bufnr, "failed to create border buffer")

  vim.api.nvim_buf_set_lines(self.bufnr, 0, size.height - 2, false, lines)

  self.winid = vim.api.nvim_open_win(self.bufnr, false, {
    style = "minimal",
    relative = self.window.config.relative,
    border = "none",
    focusable = false,
    width = size.width,
    height = size.height,
    row = position.row,
    col = position.col,
    zindex = self.window.zindex - 1,
  })
  assert(self.winid, "failed to create border window")

  vim.api.nvim_win_set_option(self.winid, 'winhl', 'Normal:' .. self.highlight)
end

function Border:get()
  if self.type == "simple" then
    if is_type("string", self.map) then
      return self.map
    end

    for position, item in pairs(self.map) do
      self.map[position] = { item, self.highlight }
    end

    return to_border_list(self.map)
  end

  self:draw()

  return nil
end

return Border
