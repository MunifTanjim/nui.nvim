# NuiSpinner

NuiSpinner is a content producer for animated loading indicators. It produces a
[`NuiText`](../text) for the current frame — drop it into any buffer, popup,
statusline, or [`NuiTable`](../table) cell. It is a thin wrapper over
[`NuiAnimation`](../animation): advancing is decoupled from timers, with an opt-in
`start()`/`stop()` layer for the common case.

_Signature:_ `NuiSpinner(options?)`

**Example**

```lua
local NuiLine = require("nui.line")
local Spinner = require("nui.spinner")
local Popup = require("nui.popup")

local popup = Popup({
  position = "50%",
  size = { width = 20, height = 1 },
  enter = false,
  focusable = false,
  border = "rounded",
})
popup:mount()

local spinner = Spinner({ animation = "dots", hl = "DiagnosticInfo" })

spinner:start(function(s)
  NuiLine():append(s:text()):render(popup.bufnr, popup.ns_id, 1)
end)

-- when the work is done:
-- spinner:stop()
-- popup:unmount()
```

## Options

### `animation`

**Type:** `string` or `{ frame: string[], interval: integer }`

**Default:** `"dots"`

A built-in preset name (uses its own frames and interval), or a table with your
own `frame` glyphs and an `interval` (milliseconds per frame). `interval` only
affects `start()` timing. See [`preset.lua`](preset.lua) for the built-in presets.

```lua
Spinner({ animation = "line" })
Spinner({ animation = { frame = { "◐", "◓", "◑", "◒" }, interval = 120 } })
```

### `hl`

**Type:** `string` (optional)

Highlight group applied to the glyph.

### `cycle`

**Type:** `integer` (optional)

Number of loops to play, then finish (a positive integer). Default: loops forever.
A finite spinner holds its last glyph and `start()` auto-stops there.

## Methods

### `spinner:text`

_Signature:_ `spinner:text()`

Returns a [`NuiText`](../text) for the current glyph. Wrap it in a
[`NuiLine`](../line) to combine it with a label.

### `spinner:next`

_Signature:_ `spinner:next()`

Advances to the next frame, wrapping after the last. Returns the spinner.

### `spinner:reset`

_Signature:_ `spinner:reset()`

Resets to the first frame. Returns the spinner.

### `spinner:start`

_Signature:_ `spinner:start(on_tick, opts?)`

Runs a timer that advances the frame every `interval` ms, calling
`on_tick(spinner)` on the main loop after each advance (repaint there). Calling
`start` again restarts. With a `cycle` count it auto-stops after the last frame.
Returns the spinner.

**Parameters**

| Name            | Type                       | Description                                                                      |
| --------------- | -------------------------- | ------------------------------------------------------------------------------- |
| `on_tick`       | `fun(spinner: NuiSpinner)` | called after each frame advance                                                  |
| `opts.on_stop?` | `fun(spinner: NuiSpinner)` | fires once when the running timer stops (completion or `stop()`; not on restart) |

### `spinner:stop`

_Signature:_ `spinner:stop()`

Stops the timer (safe when not running); fires `on_stop` once if it stopped a
running timer. Returns the spinner.

## Wiki Page

You can find additional documentation/examples/guides/tips-n-tricks in [nui.spinner wiki page](https://github.com/MunifTanjim/nui.nvim/wiki/nui.spinner).
