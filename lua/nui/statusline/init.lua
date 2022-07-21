local function get_item_string(options)
  return string.format("%%-0%s.%s%s", options.min_width, options.max_width, options.item)
end

local function init(class, options)
  ---@type NuiStatusLine
  local self = setmetatable({}, { __index = class })

  self._ = {
    generator = options.generator,
  }

  return self
end

---@class NuiStatusLine
local StatusLine = setmetatable({
  super = nil,
}, {
  __call = init,
  __name = "NuiSplit",
})

---@return string
function StatusLine:get()
  local statusline = ""
  if self.generator then
    statusline = statusline .. "%!" .. self.generator
  end

  return statusline
end

---@alias NuiStatusLine.constructor fun(options: table): NuiStatusLine
---@type NuiStatusLine|NuiStatusLine.constructor
local NuiStatusLine = StatusLine

return NuiStatusLine
