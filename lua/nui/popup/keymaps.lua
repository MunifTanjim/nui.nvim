local is_type = require("nui.utils").is_type

local keymaps = {}

local storage = setmetatable({}, {
  __index = function(tbl, key)
    rawset(tbl, key, { _next_handler_id = 1, keys = {}, handlers = {} })
    return tbl[key]
  end
})

local function get_key_id(mode, key)
  return string.format(
    "%s---%s",
    mode,
    vim.api.nvim_replace_termcodes(key, true, true, true)
  )
end

local function get_next_handler_id(bufnr, handler)
  local handler_id = storage[bufnr]._next_handler_id
  storage[bufnr]._next_handler_id = handler_id + 1
  return handler_id
end

function keymaps.execute(bufnr, handler_id)
  local handler = storage[bufnr].handlers[handler_id]
  handler(bufnr)
end

function keymaps.set(bufnr, mode, key, handler, opts, force)
  if not is_type("function", handler) then
    error("handler must be function")
  end

  local key_id = get_key_id(mode, key)

  if storage[bufnr].keys[key_id] and not force then
    return false
  end

  local handler_id = get_next_handler_id(bufnr, handler)

  storage[bufnr].keys[key_id] = true
  storage[bufnr].handlers[handler_id] = handler

  local handler_cmd = string.format(
    "<cmd>lua require('nui.popup.keymaps').execute(%s, %s)<CR>",
    bufnr,
    handler_id
  )

  vim.api.nvim_buf_set_keymap(
    bufnr,
    mode,
    key,
    handler_cmd,
    opts
  )

  return true
end

function keymaps.register_cleanup(bufnr)
  vim.api.nvim_exec(
    string.format(
      "autocmd BufDelete <buffer=%s> ++once lua require('nui.popup.keymaps').run_cleanup(%s)",
      bufnr,
      bufnr
    ),
    false
  )
end

function keymaps.run_cleanup(bufnr)
  storage.handler[bufnr] = nil
end

return keymaps
