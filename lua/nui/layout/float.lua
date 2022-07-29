local utils = require("nui.utils")
local layout_utils = require("nui.layout.utils")

local u = {
  is_type = utils.is_type,
  calculate_window_size = layout_utils.calculate_window_size,
}

local float = {}

local function get_child_position(canvas_position, current_position, box_dir)
  if box_dir == "row" then
    return {
      row = canvas_position.row,
      col = current_position.col,
    }
  elseif box_dir == "col" then
    return {
      col = canvas_position.col,
      row = current_position.row,
    }
  end
end

---@param parent table Layout.Box
---@param child table Layout.Box
---@param container_size table
---@param growable_dimension_per_factor? number
local function get_child_size(parent, child, container_size, growable_dimension_per_factor)
  local child_size = {
    width = child.size.width,
    height = child.size.height,
  }

  if child.grow and growable_dimension_per_factor then
    if parent.dir == "col" then
      child_size.height = math.floor(growable_dimension_per_factor * child.grow)
    else
      child_size.width = math.floor(growable_dimension_per_factor * child.grow)
    end
  end

  local outer_size = u.calculate_window_size(child_size, container_size)

  local inner_size = {
    width = outer_size.width,
    height = outer_size.height,
  }

  if child.component then
    if child.component.border then
      inner_size.width = inner_size.width - child.component.border._.size_delta.width
      inner_size.height = inner_size.height - child.component.border._.size_delta.height
    end
  end

  return outer_size, inner_size
end

function float.process(box, meta)
  if box.mount or box.component or not box.box then
    return error("invalid paramter: box")
  end

  local canvas_size = meta.canvas_size
  if not u.is_type("number", canvas_size.width) or not u.is_type("number", canvas_size.height) then
    return error("invalid value: box.size")
  end

  local current_position = {
    col = 0,
    row = 0,
  }

  local growable_child_factor = 0

  for _, child in ipairs(box.box) do
    if meta.process_growable_child or not child.grow then
      local position = get_child_position(meta.position, current_position, box.dir)
      local outer_size, inner_size = get_child_size(box, child, canvas_size, meta.growable_dimension_per_factor)

      if child.component then
        child.component:set_layout({
          size = inner_size,
          relative = {
            type = "win",
            winid = meta.winid,
          },
          position = position,
        })
      else
        float.process(child, {
          winid = meta.winid,
          canvas_size = outer_size,
          position = position,
        })
      end

      current_position.col = current_position.col + outer_size.width
      current_position.row = current_position.row + outer_size.height
    end

    if child.grow then
      growable_child_factor = growable_child_factor + child.grow
    end
  end

  if meta.process_growable_child or growable_child_factor == 0 then
    return
  end

  local growable_width = canvas_size.width - current_position.col
  local growable_height = canvas_size.height - current_position.row
  local growable_dimension = box.dir == "col" and growable_height or growable_width
  local growable_dimension_per_factor = growable_dimension / growable_child_factor

  float.process(box, {
    winid = meta.winid,
    canvas_size = meta.canvas_size,
    position = meta.position,
    process_growable_child = true,
    growable_dimension_per_factor = growable_dimension_per_factor,
  })
end

return float
