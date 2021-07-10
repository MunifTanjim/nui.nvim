local is_type = require("nui.utils").is_type

local cleanup = {
  __winids_by_bufnr = {},
}

function cleanup.register(bufnr, winids)
  cleanup.__winids_by_bufnr[bufnr] = winids

  vim.api.nvim_exec(
    string.format(
      "autocmd WinLeave,BufLeave,BufDelete <buffer=%s> ++once ++nested lua require('nui.window.cleanup').run(%s)",
      bufnr,
      bufnr
    ),
    false
  )
end

function cleanup.run(bufnr)
  local winids = cleanup.__winids_by_bufnr[bufnr]

  cleanup.__winids_by_bufnr[bufnr] = nil

  if not is_type("table", winids) then
    return
  end

  for _, winid in ipairs(winids) do
    local bufnr = vim.api.nvim_win_get_buf(winid)

    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_close(winid, true)
    end
  end
end

return cleanup
