cache = true
-- https://luacheck.readthedocs.io/en/stable/warnings.html
ignore = {
  "211/_.*",
  "212/_.*",
  "213/_.*",
}
include_files = { "*.luacheckrc", "lua/nui" }
read_globals = { "vim" }
std = "luajit"

-- vim: set filetype=lua :
