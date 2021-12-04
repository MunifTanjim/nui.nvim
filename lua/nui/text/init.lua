local _ = require("nui.utils")._
local is_type = require("nui.utils").is_type

local Text = {
  name = "NuiText",
  super = nil,
}

---@param content string text content
---@param highlight? string|table data for highlight
local function init(class, content, highlight)
  local self = setmetatable({}, class)
  self:set(content, highlight)
  return self
end

---@param content string text content
---@param highlight? string|table data for highlight
function Text:set(content, highlight)
  if self._content ~= content then
    self._content = content
    self._length = vim.fn.strlen(content)
    self._width = vim.api.nvim_strwidth(content)
  end

  self._highlight = is_type("string", highlight) and { group = highlight } or highlight
end

---@return string
function Text:content()
  return self._content
end

---@return number
function Text:length()
  return self._length
end

---@return number
function Text:width()
  return self._width
end

---@param bufnr number buffer number
---@param linenr number line number (1-indexed)
---@param byte_start number start byte position (0-indexed)
---@param ns_id? number namespace id
---@return nil
function Text:highlight(bufnr, linenr, byte_start, ns_id)
  if not self._highlight then
    return
  end

  ns_id = ns_id or self._highlight.ns_id or -1

  local byte_end = byte_start + self:length()

  vim.api.nvim_buf_add_highlight(bufnr, ns_id, self._highlight.group, linenr - 1, byte_start, byte_end)
end

---@param bufnr number buffer number
---@param linenr_start number start line number (1-indexed)
---@param byte_start number start byte position (0-indexed)
---@param linenr_end? number end line number (1-indexed)
---@param byte_end? number end byte position (0-indexed)
---@param ns_id? number namespace id
---@return nil
function Text:render(bufnr, linenr_start, byte_start, linenr_end, byte_end, ns_id)
  local row_start = linenr_start - 1
  local row_end = linenr_end and linenr_end - 1 or row_start

  local col_start = byte_start
  local col_end = byte_end or byte_start + self:length()

  local content = self:content()

  vim.api.nvim_buf_set_text(bufnr, row_start, col_start, row_end, col_end, { content })

  self:highlight(bufnr, linenr_start, byte_start, ns_id)
end

---@param bufnr number buffer number
---@param linenr_start number start line number (1-indexed)
---@param char_start number start character position (0-indexed)
---@param linenr_end? number end line number (1-indexed)
---@param char_end? number end character position (0-indexed)
---@param ns_id? number namespace id
---@return nil
function Text:render_char(bufnr, linenr_start, char_start, linenr_end, char_end, ns_id)
  char_end = char_end or char_start + self:width()
  local byte_range = _.char_to_byte_range(bufnr, linenr_start, char_start, char_end)
  self:render(bufnr, linenr_start, byte_range[1], linenr_end, byte_range[2], ns_id)
end

local TextClass = setmetatable({
  __index = Text,
}, {
  __call = init,
  __index = Text,
})

return TextClass
