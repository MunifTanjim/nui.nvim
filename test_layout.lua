for pkg_name in pairs(package.loaded) do
  if pkg_name:match("^nui") then
    package.loaded[pkg_name] = nil
  end
end

local Layout = require("nui.layout")
local Popup = require("nui.popup")
local Menu = require("nui.menu")

local popup = {
  a = Popup({ border = "single" }),
  b = Popup({ border = "single" }),
  c = Popup({ border = "single", focusable = false }),
}

local menu = {
  a = Menu({ border = "single" }, {
    lines = {
      Menu.separator("Group One"),
      Menu.item("Item 1"),
      Menu.item("Item 2"),
      Menu.separator("Group Two", {
        char = "-",
        text_align = "right",
      }),
      Menu.item("Item 3"),
      Menu.item("Item 4"),
    },
    keymap = {
      focus_next = { "j", "<Down>", "<Tab>" },
      focus_prev = { "k", "<Up>", "<S-Tab>" },
      close = { "<Esc>", "<C-c>" },
      submit = { "<CR>", "<Space>" },
    },
    on_close = function()
      print("CLOSED")
    end,
    on_submit = function(item)
      print("SUBMITTED", vim.inspect(item))
    end,
  }),
}

local layout = Layout(
  {
    relative = "editor",
    position = "50%",
    size = { height = 10, width = 60 },
  },
  Layout.Box({
    Layout.Box(popup.a, { grow = 1 }),
    Layout.Box(menu.a, { grow = 1 }),
  }, { dir = "row" })
)

_G.l = layout
_G.p = popup

for _, p in pairs(popup) do
  p:on("BufLeave", function()
    vim.schedule(function()
      local bufnr = vim.api.nvim_get_current_buf()
      for _, lp in pairs(popup) do
        if lp.bufnr == bufnr then
          return
        end
      end
      layout:unmount()
    end)
  end)
end

layout:mount()

-- vim.api.nvim_set_current_win(popup.a.winid)
