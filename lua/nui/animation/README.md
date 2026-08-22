# NuiAnimation

NuiAnimation maps a point in time to a frame value and remembers the current one.
It is rendering- and clock-agnostic: you decide what a frame is and when to
advance. The core (`frame`, `next`, `seek`, `reset`) is a pure state machine; an
opt-in `start()`/`stop()` layer runs a `vim.uv` timer for you.

The `frame` option is either:

- a **list** of values — steps through them, wrapping after the last (what
  [`NuiSpinner`](../spinner) is built on), or
- a **function** `fun(t) -> value` — maps eased progress `t` (`0`–`1`) to a value,
  looping every `duration` milliseconds.

_Signature:_ `NuiAnimation(options)`

**Example**

```lua
local Animation = require("nui.animation")
local NuiLine = require("nui.line")
local Popup = require("nui.popup")

local popup = Popup({
  position = "50%",
  size = { width = 20, height = 1 },
  enter = false,
  focusable = false,
  border = "rounded",
})
popup:mount()

local animation = Animation({
  frame = function(t)
    return string.format("%3d%%", math.floor(t * 100 + 0.5))
  end,
  duration = 1500,
  easing = "out_cubic",
  interval = 16, -- ~60fps
})

animation:start(function(a)
  NuiLine():append(a:frame()):render(popup.bufnr, popup.ns_id, 1)
end)

-- when the work is done:
-- animation:stop()
-- popup:unmount()
```

## Options

### `frame`

**Type:** `any[]` or `fun(t: number): any`

A non-empty list of frame values, or a function mapping eased progress `t`
(`0`–`1`) to a value. A function requires `duration`.

### `interval`

**Type:** `integer` (optional)

Milliseconds per step: how much `next()` advances, the `start()` tick period, and
(for a list) each frame's duration under `seek()`. Required by `next()`,
`start()`, and `seek()` on a list frame; for a function, set it to your target
frame period (e.g. `16` for ~60fps).

### `duration`

**Type:** `integer` (required for a function frame)

Milliseconds per loop when `frame` is a function. Progress wraps at `duration`,
approaching but never reaching `1`.

### `easing`

**Type:** `string` or `fun(t: number): number` (optional)

Easing applied to progress — a built-in preset name or a function mapping `t`
(`0`–`1`) to an eased value. For a function frame it shapes the value passed in;
for a list it shapes the frame progression across a cycle. Default: `linear`.

Presets: `linear`, plus `in_` / `out_` / `in_out_` for each family — `sine`,
`quad`, `cubic`, `quart`, `quint`, `expo`, `circ`, `back`, `elastic`, `bounce`.
The `back`, `elastic`, and `bounce` families overshoot past `0`/`1` mid-way.

For a custom curve, pass a function or build one from a cubic Bézier:
`require("nui.animation.easing").cubic_bezier(x1, y1, x2, y2)` — control points
`(x1, y1)` / `(x2, y2)`, endpoints fixed at `(0, 0)` / `(1, 1)`, `x1`/`x2` in
`[0, 1]`.

### `cycle`

**Type:** `integer` (optional)

Number of loops to play, then finish (a positive integer). Default: loops
forever. A finite animation holds its final frame — `next`/`seek` clamp instead
of wrapping, and `start()` auto-stops after the last frame. `reset()` replays.

## Methods

### `animation:frame`

_Signature:_ `animation:frame()`

Returns the current frame value.

### `animation:next`

_Signature:_ `animation:next()`

Advances by one `interval`. Returns the animation.

### `animation:seek`

_Signature:_ `animation:seek(elapsed)`

Sets the frame to the one at `elapsed` milliseconds. Feed a real clock
(`uv.now() - started_at`) for jitter-correcting playback. Returns the animation.

### `animation:reset`

_Signature:_ `animation:reset()`

Returns to the start. Returns the animation.

### `animation:start`

_Signature:_ `animation:start(on_tick, opts?)`

Runs a timer that advances every `interval` ms, calling `on_tick(animation)` on
the main loop after each advance (repaint there). Requires `interval`; calling
`start` again restarts. With a `cycle` count it auto-stops after the last frame.
Returns the animation.

**Parameters**

| Name            | Type                           | Description                                                                      |
| --------------- | ------------------------------ | ------------------------------------------------------------------------------- |
| `on_tick`       | `fun(animation: NuiAnimation)` | called after each frame advance                                                  |
| `opts.on_stop?` | `fun(animation: NuiAnimation)` | fires once when the running timer stops (completion or `stop()`; not on restart) |

### `animation:stop`

_Signature:_ `animation:stop()`

Stops the timer (safe when not running); fires `on_stop` once if it stopped a
running timer. Returns the animation.

## Wiki Page

You can find additional documentation/examples/guides/tips-n-tricks in [nui.animation wiki page](https://github.com/MunifTanjim/nui.nvim/wiki/nui.animation).
