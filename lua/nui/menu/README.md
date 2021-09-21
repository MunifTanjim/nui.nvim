# Menu

`Menu` is abstraction layer on top of `Popup`.

```lua
local Menu = require("nui.menu")
local event = require("nui.utils.autocmd").event

local popup_options = {
  relative = "cursor",
  position = {
    row = 1,
    col = 0,
  },
  border = {
    style = "rounded",
    highlight = "FloatBorder",
    text = {
      top = "[Choose Item]",
      top_align = "center",
    },
  },
  highlight = "Normal:Normal",
}

local menu = Menu(popup_options, {
  lines = {
    Menu.separator("Group One"),
    Menu.item("Item 1"),
    Menu.item("Item 2"),
    Menu.separator("Group Two"),
    Menu.item("Item 3"),
    Menu.item("Item 4"),
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

You can manipulate the assocciated buffer and window using the
`split.bufnr` and `split.winid` properties.

**NOTE**: the first argument accepts options for `nui.popup` component.

## Options

### `lines`

**Type:** `table`

**`Menu.item(item, props)`**

`Menu.item` is used to create an item object for the `Menu`. You also get this
object when `on_submit` is called.

| Usage                                  | Result                                     |
| -------------------------------------- | ------------------------------------------ |
| `Menu.item("Name")`                    | `{ text = "Name", type = "item" }`         |
| `Menu.item("Name", { id = 1 })`        | `{ id = 1, text = "Name", type = "item" }` |
| `Menu.item({ id = 1, text = "Name" })` | `{ id = 1, text = "Name", type = "item" }` |

The Result is what you get as the argument of `on_submit` callback function.
You can include whatever you want in the item object.

### `max_height`

**Type:** `number`

### `max_width`

**Type:** `number`

### `separator`

**Type:** `table`

**Example**

```lua
separator = {
  char = "-",
  text_align = "right",
},
```

### `keymap`

**Type:** `table`

Key mappings for the menu.

**Example**

```lua
keymap = {
  close = { "<Esc>", "<C-c>" },
  focus_next = { "j", "<Down>", "<Tab>" },
  focus_prev = { "k", "<Up>", "<S-Tab>" },
  submit = { "<CR>" },
},
```

### `on_close`

**Type:** `function`

Callback function, called when menu is closed.

### `on_submit`

**Type:** `function`

Callback function, called when menu is submitted.

## Methods

Methods from `nui.popup` are also available for `nui.menu`.
