local mod = {}

--luacheck: push no max line length

---@alias nui_bar_core_expression_context { ctx?: boolean|number|string|table, bufnr: integer, winid: integer, tabid: integer, is_focused: boolean }
---@alias nui_bar_core_click_handler fun(handler_id: integer, click_count: integer, mouse_button: string, modifiers: string, context: nui_bar_core_expression_context):nil
---@alias nui_bar_core_expression_fn fun(context: nui_bar_core_expression_context):string

--luacheck: pop

local fn_storage = {
  _next_id = 1,
  ---@type table<function, integer>
  id_by_ref = {},
  ---@type table<integer, function>
  ref_by_id = {},
  ---@type table<integer, any>
  ctx_by_id = {},
  ---@type table<string, integer>
  id_by_external_id = {},
}

---@param external_id? string
---@return integer fn_id
---@return boolean is_fresh
local function get_next_fn_id(external_id)
  if fn_storage.id_by_external_id[external_id] then
    return fn_storage.id_by_external_id[external_id], false
  end
  local fn_id = fn_storage._next_id
  fn_storage._next_id = fn_id + 1
  if external_id then
    fn_storage.id_by_external_id[external_id] = fn_id
  end
  return fn_id, true
end

---@param fn function
---@param opts? { id?: string, context?: nui_bar_core_item_options_context }
---@return integer fn_id
local function store_fn(fn, opts)
  if fn_storage.id_by_ref[fn] then
    local old_fn_id, ctx = fn_storage.id_by_ref[fn], opts and opts.context
    if fn_storage.ctx_by_id[old_fn_id] ~= ctx then
      fn_storage.ctx_by_id[old_fn_id] = ctx
    end
    return old_fn_id
  end

  local fn_id, is_fresh = get_next_fn_id(opts and opts.id)
  if not is_fresh then
    fn_storage.id_by_ref[fn_storage.ref_by_id[fn_id]] = nil
  end

  fn_storage.id_by_ref[fn] = fn_id
  fn_storage.ref_by_id[fn_id] = fn
  fn_storage.ctx_by_id[fn_id] = opts and opts.context
  return fn_id
end

---@param ctx? boolean|number|string|table
---@return nui_bar_core_expression_context
local function create_expression_context(ctx)
  local context = {
    ctx = ctx,
    bufnr = vim.api.nvim_get_current_buf(),
    winid = vim.api.nvim_get_current_win(),
    tabid = vim.api.nvim_get_current_tabpage(),
  }
  context.is_focused = tostring(context.winid) == vim.g.actual_curwin

  return context
end

_G.nui_bar_core_click_handler = function(fn_id, click_count, mouse_button, modifiers)
  if fn_storage.ref_by_id[fn_id] then
    local ctx = fn_storage.ctx_by_id[fn_id]
    fn_storage.ref_by_id[fn_id](
      fn_id,
      click_count,
      mouse_button,
      modifiers,
      type(ctx) == "function" and ctx(create_expression_context()) or create_expression_context(ctx)
    )
  end
end

_G.nui_bar_core_expression_fn = function(fn_id)
  if fn_storage.ref_by_id[fn_id] then
    local ctx = fn_storage.ctx_by_id[fn_id]
    return fn_storage.ref_by_id[fn_id](
      type(ctx) == "function" and ctx(create_expression_context()) or create_expression_context(ctx)
    )
  end
  return ""
end

---@param ctx? boolean|number|string|table
---@return nui_bar_core_expression_context
local function create_generator_context(ctx)
  local winid = vim.g.statusline_winid
  local context = {
    ctx = ctx,
    bufnr = vim.api.nvim_win_get_buf(winid),
    winid = winid,
    tabid = vim.api.nvim_win_get_tabpage(winid),
  }
  context.is_focused = winid == vim.api.nvim_get_current_win()

  return context
end

_G.nui_bar_core_generator_fn = function(fn_id)
  if fn_storage.ref_by_id[fn_id] then
    local ctx = fn_storage.ctx_by_id[fn_id]
    return fn_storage.ref_by_id[fn_id](
      type(ctx) == "function" and ctx(create_generator_context()) or create_generator_context(ctx)
    )
  end
  return ""
end

--luacheck: push no max line length

---@alias nui_bar_core_item_options { align?: 'left'|'right', leading_zero?: boolean, min_width?: integer, max_width?: integer }
---@alias nui_bar_core_item_options_context nil|boolean|number|string|table|fun(context: nui_bar_core_expression_context):nui_bar_core_expression_context
---@alias nui_bar_core_expression_options nui_bar_core_item_options|{ context?: nui_bar_core_item_options_context, expand?: boolean, id?: string, is_vimscript?: boolean }

--luacheck: pop

---@param code string
---@param opts? nui_bar_core_item_options
---@return string item
function mod.code(code, opts)
  if not opts then
    return "%" .. code
  end

  local parts = { "%" }

  if opts.align == "left" then
    parts[#parts + 1] = "-"
  end

  if opts.leading_zero then
    parts[#parts + 1] = "0"
  end

  if opts.min_width then
    parts[#parts + 1] = tostring(opts.min_width)
  end

  if opts.max_width then
    parts[#parts + 1] = "." .. opts.max_width
  end

  parts[#parts + 1] = code

  return table.concat(parts)
end

---@param item string
---@param opts { context?: nui_bar_core_item_options_context, id?: string, on_click: string|nui_bar_core_click_handler }
---@return string clickable_item
function mod.clickable(item, opts)
  local on_click = opts.on_click
  local is_lua_fn = type(on_click) == "function"

  local parts = {
    "%",
    is_lua_fn and store_fn(on_click, opts) or 0,
    "@",
    is_lua_fn and "v:lua.nui_bar_core_click_handler" or on_click,
    "@",
    item,
    "%T",
  }

  return table.concat(parts)
end

---@param expression number|string|nui_bar_core_expression_fn
---@param opts? nui_bar_core_expression_options
---@return string expression_item
function mod.expression(expression, opts)
  local expand = opts and opts.expand

  ---@type (number|string)[]
  local parts = {
    expand and "%{%" or mod.code("{", opts),
  }

  if type(expression) == "function" then
    parts[#parts + 1] = "v:lua.nui_bar_core_expression_fn(" .. store_fn(expression, opts) .. ")"
  elseif opts and opts.is_vimscript then
    parts[#parts + 1] = expression
  else
    parts[#parts + 1] = "luaeval('" .. string.gsub(tostring(expression), "'", "''") .. "')"
  end

  parts[#parts + 1] = expand and "%}" or "}"

  return table.concat(parts)
end

---@param item number|string
---@param opts? nui_bar_core_item_options|{ tabnr?: integer, close?: boolean }
---@return string label_item
function mod.label(item, opts)
  if opts and opts.tabnr then
    local marker = "T"
    if opts.close then
      marker = "X"
      if opts.tabnr == 0 then
        opts.tabnr = 999
      end
    end

    return table.concat({
      "%",
      opts.tabnr,
      marker,
      item,
      "%",
      marker,
    })
  end

  return mod.literal(item, opts)
end

---@param item boolean|number|string
---@param opts? nui_bar_core_item_options
---@return string literal_item
function mod.literal(item, opts)
  if not opts then
    return (string.gsub(tostring(item), "%%", "%%%%"))
  end

  opts.is_vimscript = true
  return mod.expression("'" .. string.gsub(tostring(item), "'", "''") .. "'", opts)
end

---@param items string|string[]
---@param opts? nui_bar_core_item_options
---@return string grouped_items
function mod.group(items, opts)
  return mod.code("(", opts) .. (type(items) == "table" and table.concat(items) or items) .. "%)"
end

-- `highlight` can be:
-- - `nil`|`0`  : reset highlight
-- - `1-9`    : treat as `hl-User1..9`
-- - `string` : highlight group name
---@param highlight? integer|string
---@return string highlight_item
function mod.highlight(highlight)
  if type(highlight) == "string" then
    return "%#" .. highlight .. "#"
  end
  return "%" .. (highlight or 0) .. "*"
end

-- The `'fillchars'` option (`stl` and `stlnc`) is used for spacer.
-- Check `:help 'fillchars'`.
---@return string spacer_item
function mod.spacer()
  return "%="
end

---@return string truncation_point_item
function mod.truncation_point()
  return "%<"
end

---@return string ruler_item
function mod.ruler()
  if vim.o.rulerformat and #vim.o.rulerformat > 0 then
    return vim.o.rulerformat
  end

  -- default: "%-14(%l,%c%V%) %P"
  return table.concat({
    mod.group({
      mod.code("l"),
      ",",
      mod.code("c"),
      mod.code("V"),
    }, { align = "left", min_width = 14 }),
    " ",
    mod.code("P"),
  })
end

---@param generator string|fun():string
---@param opts? { context?: nui_bar_core_item_options_context, id?: string }
function mod.generator(generator, opts)
  if type(generator) == "function" then
    return "%!v:lua.nui_bar_core_generator_fn(" .. store_fn(generator, opts) .. ")"
  end

  return "%!" .. generator
end

return mod
