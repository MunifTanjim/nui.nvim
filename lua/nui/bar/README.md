# Bar (Work-in-Progress)

Abstraction for:

- `'rulerformat'`
- `'statusline'`
- `'tabline'`
- `'winbar'`

## `core`

**Context**:

Context is used with the following items:

- [`core.clickable`](#coreclickable)
- [`core.expression`](#coreexpression)
- [`core.generator`](#coregenerator)

The context table looks like this:

```
{
  ctx?: boolean | number | string | table,
  bufnr: integer,
  winid: integer,
  tabid: integer,
  is_focused: boolean
}
```

The `.ctx` field can be controlled by passing `.context` to the options for the
above mentioned items.

Any non-function value passed as `.context` will automatically be attached to
the `.ctx` field of the context table.

If a `function` is passed as `.context`, this should be the signature:
`(context: table) -> table`.

It will receive a context table. It can mutate the table to add more data to it.
It is recommended to use the `.ctx` field to store any extra data. And it should
return the same table.

**Lua Function**:

Lua Function is supported for the following items:

- [`core.clickable`](#coreclickable)
- [`core.expression`](#coreexpression)
- [`core.generator`](#coregenerator)

If you're creating those items on-the-fly, it is highly recommended to use the
same function reference. Otherwise it might lead to memory leak.

As a safety measure, you can pass a unique `.id` to the options for those items.
`nui.bar.core` will make sure not to leak memory if `.id` is same for multiple
calls to those items.

### `core.clickable`

_Signature:_ `core.clickable(item: string, options: table) -> string`

`item` can be any `string` that defines part of the bar.

`options`:

| Key        | Type                                                   | Description           |
| ---------- | ------------------------------------------------------ | --------------------- |
| `id`       | `string`                                               | click handler id      |
| `context`  | `boolean` / `number` / `string` / `table` / `function` | click handler context |
| `on_click` | (_required_) `string` / `function`                     | click handler         |

If `on_click` is `string`, it is considered name of a vimscript function.

If `on_click` is `function`, the signature is:

`(handler_id: integer, click_count: integer, mouse_button: string, modifiers: string, context: table) -> nil`.

### `core.code`

_Signature:_ `core.code(code: string, options?: table) -> string`

`code` is a one letter code, described in `:help 'statusline'`.

`options`:

| Key            | Type                 | Description             |
| -------------- | -------------------- | ----------------------- |
| `align`        | `"left"` / `"right"` | alignment               |
| `leading_zero` | `boolean`            | leading zero for number |
| `min_width`    | `integer`            | minimum width           |
| `max_width`    | `integer`            | maximum width           |

### `core.expression`

_Signature:_ `core.expression(expression: number|string|function, options?: table) -> string`

`expression` can be `number` / `string` / `function`.

The `function` signature is: `(context: table) -> string`.

`options`:

| Key            | Type                                                   | Description                   |
| -------------- | ------------------------------------------------------ | ----------------------------- |
| `id`           | `string`                                               | expression function id        |
| `context`      | `boolean` / `number` / `string` / `table` / `function` | expression function context   |
| `expand`       | `boolean`                                              | flag for result expansion     |
| `expression`   | `string`                                               | expression                    |
| `is_vimscript` | `boolean`                                              | flag for vimscript expression |

If `.is_vimscript` is `true`, `number` / `string` is treated as vimscript.

If `.expand` is not `true`, options from [`core.code`](#corecode) are also accepted.

### `core.group`

_Signature:_ `core.group(items: string|string[], options) -> string`

`item` can be any `string` / `string[]` that defines part of the bar.

`options` is the same as [`core.code`](#corecode).

### `core.highlight`

_Signature:_ `core.highlight(highlight?: integer|string) -> string`

`highlight` can be one of the followings:

| Type                   | Description                                             |
| ---------------------- | ------------------------------------------------------- |
| `nil` / `0`            | reset highlight                                         |
| `integer` (`1` to `9`) | treat as `User1` to `User9` (check `:help hl-User1..9`) |
| `string`               | highlight group name                                    |

### `core.label`

_Signature:_ `core.label(item: number|string, options?: table) -> string`

`item` can be any `string` that defines part of the bar.

`options`:

| Key     | Type      | Description              |
| ------- | --------- | ------------------------ |
| `tabnr` | `integer` | tab number               |
| `close` | `boolean` | flag for tab close label |

If `tabnr` is not present, `options` is the same as [`core.literal`](#coreliteral).

### `core.literal`

_Signature:_ `core.literal(item: boolean|number|string, options?: table) -> string`

`item` can be any `boolean` / `number` / `string`.

`options` is the same as [`core.code`](#corecode).

### `core.spacer`

_Signature:_ `core.spacer() -> string`

### `core.truncation_point`

_Signature:_ `core.truncation_point() -> string`

### `core.ruler`

_Signature:_ `core.ruler() -> string`

Returns the value of `'rulerformat'` option (check `:help 'rulerformat'`).

### `core.generator`

_Signature:_ `core.generator(generator: string|function, options?: table) -> string`

`generator` can be `string` (treated as vimscript) or `function`.

The `function` signature is: `(context: table) -> string`.

`options`:

| Key       | Type                                                   | Description                |
| --------- | ------------------------------------------------------ | -------------------------- |
| `id`      | `string`                                               | generator function id      |
| `context` | `boolean` / `number` / `string` / `table` / `function` | generator function context |

## Wiki Page

You can find additional documentation/examples/guides/tips-n-tricks in [nui.bar wiki page](https://github.com/MunifTanjim/nui.nvim/wiki/nui.bar).
