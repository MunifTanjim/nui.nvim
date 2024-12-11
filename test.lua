for pkg_name in pairs(package.loaded) do
  if pkg_name:match("^nui") then
    package.loaded[pkg_name] = nil
  end
end

local Popup = require("nui.popup")
local Input = require("nui.input")
local Layout = require("nui.layout")

local popup = Popup({
  enter = false,
  focusable = true,
})

local input = Input({}, {
  prompt = "> ",
  default_value = "Hello",
  on_close = function()
    print("Input Closed!")
  end,
  on_submit = function(value)
    print("Input Submitted: " .. value)
  end,
})

local layout = Layout(
  {
    position = "50%",
    size = {
      width = 100,
      height = "40%",
    },
  },
  Layout.Box({
    Layout.Box(popup, { size = "80%" }),
    Layout.Box(input, { size = "20%" }),
  }, { dir = "col" })
)

layout:mount()
