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

List of menu items.

**`Menu.item(text, data)`**

`Menu.item` is used to create an item object for the `Menu`. You also get this
object when `on_submit` is called.

| Usage                                  | Result                       |
| -------------------------------------- | ---------------------------- |
| `Menu.item("Name")`                    | `{ text = "Name" }`          |
| `Menu.item(NuiText("Name"))`           | `{ text = NuiText("Name") }` |
| `Menu.item("Name", { id = 1 })`        | `{ id = 1, text = "Name" }`  |
| `Menu.item({ id = 1, text = "Name" })` | `{ id = 1, text = "Name" }`  |

The result is what you get as the argument of `on_submit` callback function.
You can include whatever you want in the item object.

**`Menu.separator(text)`**

`Menu.separator` is used to create a menu item that can't be focused.

You can just use `Menu.item` only and implement `Menu.separator`'s behavior
by providing a custom `should_skip_item` function.

### `prepare_item(item)`

**Type:** `function`

If provided, this function is used for preparing each menu item.

The return value should be a `NuiLine` object or `string`.

### `should_skip_item(item)`

**Type:** `function`

If provided, this function is used to determine if an item should be
skipped when focusing previous/next item.

The return value should be `boolean`.

By default, items created by `Menu.separator` are skipped.

### `max_height`

**Type:** `number`

Maximum height of the menu.

### `min_height`

**Type:** `number`

Minimum height of the menu.

### `max_width`

**Type:** `number`

Maximum width of the menu.

### `min_width`

**Type:** `number`

Minimum width of the menu.

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

### `on_change(item, menu)`

**Type:** `function`

Callback function, called when menu item is focused.

### `on_close()`

**Type:** `function`

Callback function, called when menu is closed.

### `on_submit(item)`

**Type:** `function`

Callback function, called when menu is submitted.

## Methods

Methods from `nui.popup` are also available for `nui.menu`.
