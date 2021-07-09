local style ={
  double  = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" },
  none    = { "" },
  rounded = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  shadow  = "shadow",
  single  = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
  solid   = { "▛", "▀", "▜", "▐", "▟", "▄", "▙", "▌" },
}

local Border = {}

function Border.create(definition, highlight)
  local border = vim.deepcopy(definition)

  if type(border) == "nil" then
    border = style["rounded"]
  elseif type(border) == "string" then
    if not style[border] then
      return error("invalid border style name")
    end

    border = style[border]
  elseif type(border) == "table" and not vim.tbl_islist(border) then
    border = { border.top_left, border.top, border.top_right, border.right, border.bottom_right, border.bottom, border.bottom_left, border.left }
  end

  if type(border) == "string" then
    return border
  end

  if type(highlight) == "string" then
    for i, item in ipairs(border) do
      if type(item) == "string" then
        border[i] = { item, highlight }
      end
    end
  end

  return border
end

return Border
