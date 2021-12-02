local NuiText = require("nui.text")

local Line = {
  name = "NuiLine",
  super = nil,
}

local function init(class)
  local self = setmetatable({}, class)

  self._chunks = {}

  return self
end

---@param text string text to add
---@param highlight? string|table data for highlight
function Line:append(text, highlight)
  local nui_text = NuiText(text, highlight)
  table.insert(self._chunks, nui_text)
end

---@return string
function Line:content()
  return table.concat(vim.tbl_map(function(chunk)
    return chunk:content()
  end, self._chunks))
end

---@param bufnr number buffer number
---@param linenr number line number (1-indexed)
---@param ns_id? number namespace id
---@return nil
function Line:highlight(bufnr, linenr, ns_id)
  local current_byte_start = 0
  for _, chunk in ipairs(self._chunks) do
    chunk:highlight(bufnr, linenr, current_byte_start, ns_id)
    current_byte_start = current_byte_start + chunk:length()
  end
end

---@param bufnr number buffer number
---@param linenr_start number start line number (1-indexed)
---@param linenr_end? number end line number (1-indexed)
---@param ns_id? number namespace id
---@return nil
function Line:render(bufnr, linenr_start, linenr_end, ns_id)
  local row_start = linenr_start - 1
  local row_end = linenr_end and linenr_end - 1 or row_start + 1
  local content = self:content()
  vim.api.nvim_buf_set_lines(bufnr, row_start, row_end, false, { content })
  self:highlight(bufnr, linenr_start, ns_id)
end

local LineClass = setmetatable({
  __index = Line,
}, {
  __call = init,
  __index = Line,
})

return LineClass
