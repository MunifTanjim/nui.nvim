local NuiText = require("nui.text")
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type

local Line = {
  name = "NuiLine",
  super = nil,
}

---@param texts? table[] NuiText objects
local function init(class, texts)
  local self = setmetatable({}, class)

  self._texts = defaults(texts, {})

  return self
end

---@param text string|table text content or NuiText object
---@param highlight? string|table data for highlight
---@return table NuiText
function Line:append(text, highlight)
  local nui_text = is_type("string", text) and NuiText(text, highlight) or text
  table.insert(self._texts, nui_text)
  return nui_text
end

---@return string
function Line:content()
  return table.concat(vim.tbl_map(function(text)
    return text:content()
  end, self._texts))
end

---@param bufnr number buffer number
---@param linenr number line number (1-indexed)
---@param ns_id? number namespace id
---@return nil
function Line:highlight(bufnr, linenr, ns_id)
  local current_byte_start = 0
  for _, text in ipairs(self._texts) do
    text:highlight(bufnr, linenr, current_byte_start, ns_id)
    current_byte_start = current_byte_start + text:length()
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
