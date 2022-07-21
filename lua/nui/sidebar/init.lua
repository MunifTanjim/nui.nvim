local Object = require("nui.object")
local Split = require("nui.split")
local u = require("nui.utils")

local noop = function() end

---@class NuiSidebarSection
local SidebarSection = Split:extend("NuiSidebarSection")

SidebarSection.static.default_options = {
  win_options = {},
}

function SidebarSection:init(options)
  SidebarSection.super.init(
    self,
    vim.tbl_deep_extend("force", options, {
      enter = false,
      relative = "win",
      position = "bottom",
    })
  )

  self.id = options.id
  self._setup = options.setup
  self._cleanup = noop
end

function SidebarSection:collapse()
  vim.api.nvim_win_set_height(self.winid, 0)
end

local function get_spacer_section(sidebar)
  return SidebarSection({
    id = "__spacer__",
    size = 1,
    setup = function(section)
      section:on("WinEnter", function()
        local winid = sidebar._.sections[1].winid
        if winid and vim.api.nvim_win_is_valid(winid) then
          vim.api.nvim_set_current_win(winid)
        end
      end)
    end,
  })
end

---@class NuiSidebar
---@field Section NuiSidebarSection
local Sidebar = Object("NuiSidebar")

function Sidebar:init(options)
  self._ = {
    position = u.defaults(options.position, "left"),
    sections = {},
  }

  options.sections[#options.sections + 1] = get_spacer_section(self)

  for i, section in ipairs(options.sections) do
    if i == 1 then
      section._.relative.type = "editor"
      section._.position = self._.position
      section._.size = self._.size
    end

    section._.win_options = vim.tbl_deep_extend("keep", section._.win_options, u.defaults(options.win_options, {}), {
      cursorline = false,
      fillchars = "eob: ",
      number = false,
      signcolumn = "no",
      statusline = " ",
    })

    section._.win_variables = vim.tbl_deep_extend(
      "keep",
      section._.win_variables,
      u.defaults(options.win_variables, {})
    )

    self._.sections[#self._.sections + 1] = section
  end
end

function Sidebar:mount()
  for i, section in ipairs(self._.sections) do
    local last_section = self._.sections[i - 1]
    vim.api.nvim_win_call(last_section and last_section.winid or 0, function()
      section:mount()
    end)
  end

  for _, section in ipairs(self._.sections) do
    local cleanup = section:_setup()
    if cleanup then
      section._cleanup = cleanup
    end
  end
end

function Sidebar:unmount()
  for _, section in ipairs(self._.sections) do
    section:_cleanup()
    section:unmount()
  end
end

function Sidebar:show()
  for i, section in ipairs(self._.sections) do
    local last_section = self._.sections[i - 1]

    vim.api.nvim_win_call(last_section and last_section.winid or 0, function()
      section:show()
    end)
  end
end

function Sidebar:hide()
  for _, section in ipairs(self._.sections) do
    section:hide()
  end
end

function Sidebar:map(mode, key, handler, opts)
  for _, section in ipairs(self._.sections) do
    section:map(mode, key, handler, opts)
  end
end

function Sidebar:on(event, handler, options)
  for _, section in ipairs(self._.sections) do
    section:on(event, handler, options)
  end
end

---@param id? string
---@return NuiSidebarSection|nil
function Sidebar:get_section(id)
  local key = id and "id" or "winid"
  local value = id or vim.api.nvim_get_current_win()
  return vim.tbl_filter(function(section)
    return section[key] == value
  end, self._.sections)[1]
end

Sidebar.static.Section = SidebarSection

---@alias NuiSidebar.constructor fun(options: table): NuiSidebar
---@type NuiSidebar|NuiSidebar.constructor
local NuiSidebar = Sidebar

return NuiSidebar
