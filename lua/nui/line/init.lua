local NuiText = require("nui.text")
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type

---@param class NuiLine
---@param texts? table[] NuiText objects
---@return NuiLine
local function init(class, texts)
  ---@type NuiLine
  local self = setmetatable({}, { __index = class })

  self._texts = defaults(texts, {})

  return self
end

---@class NuiLine
local Line = setmetatable({
  super = nil,
}, {
  __call = init,
  __name = "NuiLine",
})

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
---@param ns_id number namespace id
---@param linenr number line number (1-indexed)
---@return nil
function Line:highlight(bufnr, ns_id, linenr)
  local current_byte_start = 0
  for _, text in ipairs(self._texts) do
    text:highlight(bufnr, ns_id, linenr, current_byte_start)
    current_byte_start = current_byte_start + text:length()
  end
end

---@param bufnr number buffer number
---@param ns_id number namespace id
---@param linenr_start number start line number (1-indexed)
---@param linenr_end? number end line number (1-indexed)
---@return nil
function Line:render(bufnr, ns_id, linenr_start, linenr_end)
  local row_start = linenr_start - 1
  local row_end = linenr_end and linenr_end - 1 or row_start + 1
  local content = self:content()
  vim.api.nvim_buf_set_lines(bufnr, row_start, row_end, false, { content })
  self:highlight(bufnr, ns_id, linenr_start)
end

---@alias NuiLine.constructor fun(texts?: NuiText[]): NuiLine
---@type NuiLine|NuiLine.constructor
local NuiLine = Line

return NuiLine
