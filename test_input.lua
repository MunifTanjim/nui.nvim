for name in pairs(package.loaded) do
  if name:find("^nui") then
    package.loaded[name] = nil
  end
end

local Input = require("nui.input")
local event = require("nui.utils.autocmd").event

local prompt_msg = "Close current file?"

local bufnr = vim.api.nvim_get_current_buf()

local input = Input({
  position = "50%",
  size = {
    width = #prompt_msg + 4,
  },
  border = {
    style = "single",
    text = {
      top = prompt_msg,
      top_align = "center",
    },
  },
  win_options = {
    winhighlight = "Normal:Normal,FloatBorder:Normal",
  },
}, {
  prompt = "> ",
  default_value = "N",
  on_close = function()
    print("Input Closed!")
  end,
  on_submit = function(value)
    print("START - on_submit")
    if value:lower() == "y" then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    print("END - on_submit")
  end,
})

input:mount()

input:on(event.BufLeave, function()
  input:unmount()
end)
