local Tree = require("nui.tree")

local eq = assert.are.same

describe("nui.tree", function()
  local winid

  before_each(function()
    winid = vim.api.nvim_get_current_win()
  end)

  it("sets t.winid and t.bufnr properly", function()
    local bufnr = vim.api.nvim_win_get_buf(winid)

    local tree = Tree({ winid = winid })

    eq(winid, tree.winid)
    eq(bufnr, tree.bufnr)
  end)

  it("sets default buf options emulating scratch-buffer", function()
    local tree = Tree({ winid = winid })

    eq(vim.api.nvim_buf_get_option(tree.bufnr, "bufhidden"), "hide")
    eq(vim.api.nvim_buf_get_option(tree.bufnr, "buflisted"), false)
    eq(vim.api.nvim_buf_get_option(tree.bufnr, "buftype"), "nofile")
    eq(vim.api.nvim_buf_get_option(tree.bufnr, "swapfile"), false)
  end)

  it("sets default win options for handling folds", function()
    local tree = Tree({ winid = winid })

    eq(vim.api.nvim_win_get_option(tree.winid, "foldcolumn"), "0")
    eq(vim.api.nvim_win_get_option(tree.winid, "foldmethod"), "manual")
    eq(vim.api.nvim_win_get_option(tree.winid, "wrap"), false)
  end)

  it("sets t.ns_id if o.ns is string", function()
    local ns = "NuiTreeTest"
    local tree = Tree({ winid = winid, ns = ns })

    local namespaces = vim.api.nvim_get_namespaces()

    eq(tree.ns_id, namespaces[ns])
  end)

  it("sets t.ns_id if o.ns is number", function()
    local ns = "NuiTreeTest"
    local ns_id = vim.api.nvim_create_namespace(ns)
    local tree = Tree({ winid = winid, ns = ns_id })

    eq(tree.ns_id, ns_id)
  end)

  it("uses o.get_node_id if provided", function()
    local node_d2 = Tree.Node({ key = "depth two" })
    local node_d1 = Tree.Node({ key = "depth one" }, { node_d2 })
    Tree({
      winid = winid,
      nodes = { node_d1 },
      get_node_id = function(node)
        return node.key
      end,
    })

    eq(node_d1:get_id(), node_d1.key)
    eq(node_d2:get_id(), node_d2.key)
  end)

  describe("default get_node_id", function()
    it("returns id using n.id", function()
      local node = Tree.Node({ id = "id", text = "text" })
      Tree({ winid = winid, nodes = { node } })

      eq(node:get_id(), "-id")
    end)

    it("returns id using parent_id + depth + n.text", function()
      local node_d2 = Tree.Node({ text = "depth two" })
      local node_d1 = Tree.Node({ text = "depth one" }, { node_d2 })
      Tree({ winid = winid, nodes = { node_d1 } })

      eq(node_d1:get_id(), string.format("-%s-%s", node_d1:get_depth(), node_d1.text))
      eq(node_d2:get_id(), string.format("%s-%s-%s", node_d2:get_parent_id(), node_d2:get_depth(), node_d2.text))
    end)

    it("returns id using random number", function()
      math.randomseed(0)
      local expected_id = "-" .. math.random()
      math.randomseed(0)

      local node = Tree.Node({})
      Tree({ winid = winid, nodes = { node } })

      eq(node:get_id(), expected_id)
    end)
  end)

  it("uses o.prepare_node if provided", function()
    local nodes = {
      Tree.Node({ text = "a" }),
      Tree.Node({ text = "b" }, {
        Tree.Node({ text = "b-1" }),
        Tree.Node({ text = "b-2" }, {
          Tree.Node({ text = "b-2-x" }),
          Tree.Node({ text = "b-2-y" }),
        }),
      }),
      Tree.Node({ text = "c" }),
    }
    local tree = Tree({
      winid = winid,
      nodes = nodes,
      prepare_node = function(node)
        return node:get_id()
      end,
    })

    tree:render()

    local lines = vim.api.nvim_buf_get_lines(tree.bufnr, 0, -1, false)

    for i, line in ipairs(lines) do
      eq(line, nodes[i]:get_id())
    end
  end)

  describe("default prepare_node", function()
    it("uses n.text", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        winid = winid,
        nodes = nodes,
      })

      tree:render()

      local lines = vim.api.nvim_buf_get_lines(tree.bufnr, 0, -1, false)

      for i, line in ipairs(lines) do
        eq(line, "  " .. nodes[i].text)
      end
    end)

    it("renders arrow if children are present", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }, {
          Tree.Node({ text = "b-1" }),
        }),
        Tree.Node({ text = "c" }),
      }
      local tree = Tree({
        winid = winid,
        nodes = nodes,
      })

      tree:render()

      eq(vim.api.nvim_buf_get_lines(tree.bufnr, 0, -1, false), {
        "  a",
        " b",
        "  c",
      })

      nodes[2]:expand()
      tree:render()

      eq(vim.api.nvim_buf_get_lines(tree.bufnr, 0, -1, false), {
        "  a",
        " b",
        "    b-1",
        "  c",
      })
    end)
  end)
end)
