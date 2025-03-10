for name in pairs(package.loaded) do
  if name:find("^nui") then
    package.loaded[name] = nil
  end
end

local Text = require("nui.text")
local Tree = require("nui.tree")
local Split = require("nui.split")

local split = Split({
  size = 10,
  position = "bottom",
})

vim.api.nvim_buf_set_lines(split.bufnr, 0, -1, false, {
  "HEADER",
  "",
  "",
  "",
  "FOOTER",
})

split:map("n", "gq", function()
  split:unmount()
end)

local tree = Tree({
  bufnr = split.bufnr,
  nodes = {
    Tree.Node({ text = "a" }),
    Tree.Node({ id = "b", text = "b" }, {
      Tree.Node({ text = Text("b-1", "GruvboxBlue") }, {
        Tree.Node({ text = "b-1-1" }),
      }),
      Tree.Node({ id = "target", text = { "b-2-a", "b-2-b", "b-2-c" } }),
    }),
    -- Tree.Node({ text = "c" }),
  },
})

local start_linenr = 3
split:map("n", "K", function()
  local b = tree:get_node("-b")
  _ = b:expand() or b:collapse()

  start_linenr = math.max(1, start_linenr - 1)
  tree:render(start_linenr)
  print(vim.inspect(tree._.linenr))
end)
split:map("n", "J", function()
  local b = tree:get_node("-b")
  _ = b:expand() or b:collapse()

  start_linenr = start_linenr + 1
  tree:render(start_linenr)
  print(vim.inspect(tree._.linenr))
end)

local function print_ll()
  local head = tree:get_node(tree._head or "")

  local items = {}
  local count = 0
  while head and count < 99 do
    if type(head.text) == "table" then
      if head.text.content then
        table.insert(items, head.text:content())
      else
        table.insert(items, table.concat(head.text, "|"))
      end
    else
      table.insert(items, head.text)
    end
    head = tree:get_node(head._next or "")
    count = count + 1
  end

  print(table.concat(items, ">"))
end

local cnode_idx = 0
local function create_node()
  cnode_idx = cnode_idx + 1
  return Tree.Node({ id = "cnode-" .. tostring(cnode_idx), text = "cnode-" .. tostring(cnode_idx) })
end

split:map("n", "a", function()
  local node = tree:get_node()
  if node then
    tree:add_node(create_node(), node:get_id())
    tree:render()
  end
end)

split:map("n", "l", function()
  local node = tree:get_node()
  if node then
    if node:has_children() then
      if node:expand() then
        tree:render()
      end
    end
  end
end)

split:map("n", "h", function()
  local node = tree:get_node()
  if node then
    if node:has_children() then
      if node:collapse() then
        tree:render()
      end
    end
  end
end)

split:map("n", "p", function()
  local info = { tree:get_node() }
  local n = info[1] and { tree:get_node(info[1]:get_id()) }
  info[1] = info[1] and info[1]:get_id()
  info[4] = n and n[2]
  info[5] = n and n[3]
  print(vim.inspect(info))
end)

split:map("n", "<Leader>p", function()
  print_ll()
end)

tree:render(start_linenr)

split:mount()

_G.split = split
_G.tree = tree
