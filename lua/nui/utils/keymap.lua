local buf_storage = require("nui.utils.buf_storage")
local is_type = require("nui.utils").is_type

local keymap = {
  storage = buf_storage.create("nui.utils.keymap", { _next_handler_id = 1, keys = {}, handlers = {} }),
}

local function store_keymap(bufnr, mode, key, handler, overwrite)
  local key_id = string.format("%s---%s", mode, vim.api.nvim_replace_termcodes(key, true, true, true))

  if keymap.storage[bufnr].keys[key_id] and not overwrite then
    return nil
  end

  keymap.storage[bufnr].keys[key_id] = true

  local handler_id = keymap.storage[bufnr]._next_handler_id
  keymap.storage[bufnr]._next_handler_id = handler_id + 1

  keymap.storage[bufnr].handlers[handler_id] = handler

  return handler_id
end

function keymap.execute(bufnr, handler_id)
  local handler = keymap.storage[bufnr].handlers[handler_id]
  if is_type("function", handler) then
    handler(bufnr)
  end
end

function keymap.set(bufnr, mode, key, handler, opts, force)
  if not is_type("function", handler) then
    error("handler must be function")
  end

  local handler_id = store_keymap(bufnr, mode, key, handler, force)

  if not handler_id then
    return false
  end

  local handler_cmd = string.format("<cmd>lua require('nui.utils.keymap').execute(%s, %s)<CR>", bufnr, handler_id)

  vim.api.nvim_buf_set_keymap(bufnr, mode, key, handler_cmd, opts)

  return true
end

return keymap
