local Tree = require("nui.tree")
local helper = require("tests.nui")

local eq = helper.eq

describe("nui.tree", function()
  local winid, bufnr

  before_each(function()
    winid = vim.api.nvim_get_current_win()
    bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_win_set_buf(winid, bufnr)
  end)

  it("sets t.winid and t.bufnr properly", function()
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

  it("sets t.ns_id if o.ns_id is string", function()
    local ns = "NuiTreeTest"
    local tree = Tree({ winid = winid, ns_id = ns })

    local namespaces = vim.api.nvim_get_namespaces()

    eq(tree.ns_id, namespaces[ns])
  end)

  it("sets t.ns_id if o.ns_id is number", function()
    local ns = "NuiTreeTest"
    local ns_id = vim.api.nvim_create_namespace(ns)
    local tree = Tree({ winid = winid, ns_id = ns_id })

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

  describe("method :get_node", function()
    it("can get node under cursor", function()
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

      vim.api.nvim_win_set_cursor(winid, { 3, 0 })

      eq(tree:get_node(), nodes[3])
    end)

    it("can get node with id", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        winid = winid,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:render()

      eq(tree:get_node("b"), nodes[2])
    end)

    it("can get node on linenr", function()
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

      eq(tree:get_node(1), nodes[1])
    end)
  end)

  describe("method :get_nodes", function()
    it("can get nodes at root", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }, {
          Tree.Node({ text = "b-1" }),
        }),
      }

      local tree = Tree({
        winid = winid,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
      })

      eq(tree:get_nodes(), nodes)
    end)

    it("can get nodes under parent node", function()
      local child_nodes = {
        Tree.Node({ text = "b-1" }),
      }

      local tree = Tree({
        winid = winid,
        nodes = {
          Tree.Node({ text = "a" }),
          Tree.Node({ text = "b" }, child_nodes),
        },
        get_node_id = function(node)
          return node.text
        end,
      })

      eq(tree:get_nodes("b"), child_nodes)
    end)
  end)

  describe("method :set_nodes", function()
    it("can set nodes at root", function()
      local tree = Tree({
        winid = winid,
        nodes = {
          Tree.Node({ text = "x" }),
        },
      })

      tree:set_nodes({
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }),
      })

      tree:render()

      eq(vim.api.nvim_buf_get_lines(tree.bufnr, 0, -1, false), {
        "  a",
        "  b",
      })

      tree:set_nodes({
        Tree.Node({ text = "c" }),
      })

      tree:render()

      eq(vim.api.nvim_buf_get_lines(tree.bufnr, 0, -1, false), {
        "  c",
      })
    end)

    it("can set nodes under parent node", function()
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
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:set_nodes({
        Tree.Node({ text = "b-2" }),
      }, "b")

      tree:get_node("b"):expand()

      tree:set_nodes({
        Tree.Node({ text = "c-1" }),
        Tree.Node({ text = "c-2" }),
      }, "c")

      tree:get_node("c"):expand()

      tree:render()

      eq(vim.api.nvim_buf_get_lines(tree.bufnr, 0, -1, false), {
        "  a",
        " b",
        "    b-2",
        " c",
        "    c-1",
        "    c-2",
      })
    end)
  end)
end)
