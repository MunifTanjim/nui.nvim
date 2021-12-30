local mod = {}

mod.eq = assert.are.same

---@param keys string
---@param mode string
function mod.feedkeys(keys, mode)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), mode or "", true)
end

---@param tbl table
---@param keys string[]
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

---@param tbl table
---@param keys string[]
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

---@param bufnr number
---@param lines string[]
---@param linenr_start? number
---@param linenr_end? number
function mod.assert_buf_lines(bufnr, lines, linenr_start, linenr_end)
  mod.eq(vim.api.nvim_buf_get_lines(bufnr, linenr_start or 0, linenr_end or -1, false), lines)
end

---@param extmark table
---@param linenr number
---@param text string
---@param hl_group string
function mod.assert_extmark(extmark, linenr, text, hl_group)
  mod.eq(extmark[2], linenr - 1)
  mod.eq(extmark[4].end_col - extmark[3], #text)
  mod.eq(mod.tbl_pick(extmark[4], { "end_row", "hl_group" }), {
    end_row = linenr - 1,
    hl_group = hl_group,
  })
end

return mod
