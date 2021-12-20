local NuiLine = require("nui.line")

local mod = {}

---@param node table NuiTreeNode
---@return string node_id id
function mod.default_get_node_id(node)
  if node.id then
    return "-" .. node.id
  end

  if node.text then
    return string.format("%s-%s-%s", node._parent_id or "", node._depth, node.text)
  end

  return "-" .. math.random()
end

---@param node table NuiTreeNode
---@return table line NuiLine
function mod.default_prepare_node(node)
  local line = NuiLine()

  line:append(string.rep("  ", node._depth - 1))

  if node:has_children() then
    line:append(node:is_expanded() and " " or " ")
  else
    line:append("  ")
  end

  if not node.text then
    error("missing node.text")
  end

  line:append(node.text)

  return line
end

return mod
