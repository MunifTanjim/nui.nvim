# Menu

`Menu` is abstraction layer on top of `Popup`.

```lua
local Menu = require("nui.menu")
local event = require("nui.utils.autocmd").event

local menu = Menu({
  position = "20%",
  size = {
    width = 20,
    height = 2,
  },
  relative = "editor",
  border = {
    highlight = "MyHighlightGroup",
    style = "single",
    text = {
      top = "Choose Something",
      top_align = "center",
    },
  },
  win_options = {
    winblend = 10,
    winhighlight = "Normal:Normal",
  },
}, {
  lines = {
    Menu.item("Item 1"),
    Menu.item("Item 2"),
    Menu.separator("Menu Group"),
    Menu.item("Item 3"),
  },
  max_width = 20,
  separator = {
    char = "-",
    text_align = "right",
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
})
```

## Menu.item(item, props)

`Menu.item` is used to create an item object for the `Menu`. You also get this
object when `on_submit` is called.

| Usage                                  | Result                                     |
| -------------------------------------- | ------------------------------------------ |
| `Menu.item("Name")`                    | `{ text = "Name", type = "item" }`         |
| `Menu.item("Name", { id = 1 })`        | `{ id = 1, text = "Name", type = "item" }` |
| `Menu.item({ id = 1, text = "Name" })` | `{ id = 1, text = "Name", type = "item" }` |

The Result is what you get as the argument of `on_submit` callback function.
You can include whatever you want in the item object.
