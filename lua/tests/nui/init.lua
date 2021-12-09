local mod = {}

mod.eq = assert.are.same

---@param keys string
---@param mode string
function mod.feedkeys(keys, mode)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), mode or "", true)
end

function mod.tbl_pick(tbl, keys)
  if not keys or #keys == 0 then
    return tbl
  end

  local new_tbl = {}
  for _, key in ipairs(keys) do
    new_tbl[key] = tbl[key]
  end
  return new_tbl
end

function mod.tbl_omit(tbl, keys)
  if not keys or #keys == 0 then
    return tbl
  end

  local new_tbl = vim.deepcopy(tbl)
  for _, key in ipairs(keys) do
    rawset(new_tbl, key, nil)
  end
  return new_tbl
end

return mod
