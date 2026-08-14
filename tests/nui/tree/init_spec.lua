pcall(require, "luacov")

local Line = require("nui.line")
local Text = require("nui.text")
local Tree = require("nui.tree")
local h = require("tests.helpers")

local eq = h.eq

describe("nui.tree", function()
  local winid, bufnr

  before_each(function()
    winid = vim.api.nvim_get_current_win()
    bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_win_set_buf(winid, bufnr)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  describe("(#deprecated) o.winid", function()
    it("throws if missing", function()
      local ok, err = pcall(function()
        return Tree({})
      end)
      eq(ok, false)
      eq(type(string.match(err, "missing bufnr")), "string")
    end)

    it("throws if invalid", function()
      local ok, err = pcall(function()
        return Tree({ winid = 999 })
      end)
      eq(ok, false)
      eq(type(string.match(err, "invalid winid ")), "string")
    end)

    it("sets t.winid and t.bufnr properly", function()
      local tree = Tree({ winid = winid })

      eq(tree.winid, winid)
      eq(tree.bufnr, bufnr)
    end)
  end)

  describe("o.bufnr", function()
    it("throws if missing", function()
      local ok, err = pcall(function()
        return Tree({})
      end)
      eq(ok, false)
      eq(type(string.match(err, "missing bufnr")), "string")
    end)

    it("throws if invalid", function()
      local ok, err = pcall(function()
        return Tree({ bufnr = 999 })
      end)
      eq(ok, false)
      eq(type(string.match(err, "invalid bufnr ")), "string")
    end)

    it("sets t.bufnr properly", function()
      local tree = Tree({ bufnr = bufnr })

      eq(tree.winid, nil)
      eq(tree.bufnr, bufnr)
    end)
  end)

  it("throws on duplicated node id", function()
    local ok, err = pcall(function()
      return Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ id = "id", text = "text" }),
          Tree.Node({ id = "id", text = "text" }),
        },
      })
    end)
    eq(ok, false)
    eq(type(err), "string")
  end)

  it("sets default buf options emulating scratch-buffer", function()
    local tree = Tree({ bufnr = bufnr })

    h.assert_buf_options(tree.bufnr, {
      bufhidden = "hide",
      buflisted = false,
      buftype = "nofile",
      swapfile = false,
    })
  end)

  describe("(#deprecated) o.win_options", function()
    it("sets default values for handling folds", function()
      local tree = Tree({ winid = winid })

      h.assert_win_options(tree.winid, {
        foldmethod = "manual",
        foldcolumn = "0",
        wrap = false,
      })
    end)

    it("sets values", function()
      local initial_statusline = vim.api.nvim_win_get_option(winid, "statusline")

      local statusline = "test: win_options " .. math.random()
      local tree = Tree({
        winid = winid,
        win_options = {
          statusline = statusline,
        },
      })

      h.assert_win_options(tree.winid, {
        statusline = statusline,
      })

      vim.api.nvim_win_set_option(tree.winid, "statusline", initial_statusline)
    end)

    it("has no effect if o.bufnr is present", function()
      local initial_statusline = vim.api.nvim_win_get_option(winid, "statusline")

      Tree({
        bufnr = bufnr,
        win_options = {
          statusline = "test: win_options" .. math.random(),
        },
      })

      h.assert_win_options(winid, {
        statusline = initial_statusline,
      })
    end)
  end)

  it("sets t.ns_id if o.ns_id is string", function()
    local ns = "NuiTreeTest"
    local tree = Tree({ bufnr = bufnr, ns_id = ns })

    local namespaces = vim.api.nvim_get_namespaces()

    eq(tree.ns_id, namespaces[ns])
  end)

  it("sets t.ns_id if o.ns_id is number", function()
    local ns = "NuiTreeTest"
    local ns_id = vim.api.nvim_create_namespace(ns)
    local tree = Tree({ bufnr = bufnr, ns_id = ns_id })

    eq(tree.ns_id, ns_id)
  end)

  it("uses o.get_node_id if provided", function()
    local node_d2 = Tree.Node({ key = "depth two" })
    local node_d1 = Tree.Node({ key = "depth one" }, { node_d2 })
    Tree({
      bufnr = bufnr,
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
      Tree({ bufnr = bufnr, nodes = { node } })

      eq(node:get_id(), "-id")
    end)

    it("returns id using parent_id + depth + n.text", function()
      local node_d2 = Tree.Node({ text = { "depth two a", Text("depth two b") } })
      local node_d1 = Tree.Node({ text = "depth one" }, { node_d2 })
      Tree({ bufnr = bufnr, nodes = { node_d1 } })

      eq(node_d1:get_id(), string.format("-%s-%s", node_d1:get_depth(), node_d1.text))
      eq(
        node_d2:get_id(),
        string.format(
          "%s-%s-%s",
          node_d2:get_parent_id(),
          node_d2:get_depth(),
          table.concat({ node_d2.text[1], node_d2.text[2]:content() }, "-")
        )
      )
    end)

    it("returns id using random number", function()
      math.randomseed(0)
      local expected_id = "-" .. math.random()
      math.randomseed(0)

      local node = Tree.Node({})
      Tree({ bufnr = bufnr, nodes = { node } })

      eq(node:get_id(), expected_id)
    end)
  end)

  it("uses o.prepare_node if provided", function()
    local function prepare_node(node, parent_node)
      if not parent_node then
        return node.text
      end

      return parent_node.text .. ":" .. node.text
    end

    local nodes = {
      Tree.Node({ text = "a" }),
      Tree.Node({ text = "b" }, {
        Tree.Node({ text = "b-1" }),
        Tree.Node({ text = "b-2" }),
      }),
      Tree.Node({ text = "c" }),
    }

    nodes[2]:expand()

    local tree = Tree({
      bufnr = bufnr,
      nodes = nodes,
      prepare_node = prepare_node,
    })

    tree:render()

    h.assert_buf_lines(tree.bufnr, {
      "a",
      "b",
      "b:b-1",
      "b:b-2",
      "c",
    })
  end)

  describe("default prepare_node", function()
    it("throws if missing n.text", function()
      local nodes = {
        Tree.Node({ txt = "a" }),
        Tree.Node({ txt = "b" }),
        Tree.Node({ txt = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
      })

      local ok, err = pcall(tree.render, tree)
      eq(ok, false)
      eq(type(err), "string")
    end)

    it("uses n.text", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = { "b-1", "b-2" } }),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        "  b-1",
        "  b-2",
        "  c",
      })
    end)

    it("renders arrow if children are present", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }, {
          Tree.Node({ text = "b-1" }),
          Tree.Node({ text = { "b-2", "b-3" } }),
        }),
        Tree.Node({ text = "c" }),
      }
      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        " b",
        "  c",
      })

      nodes[2]:expand()
      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        " b",
        "    b-1",
        "    b-2",
        "    b-3",
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
        bufnr = bufnr,
        nodes = nodes,
      })

      tree:render()

      local linenr = 3

      vim.api.nvim_win_set_cursor(winid, { linenr, 0 })

      eq({ tree:get_node() }, { nodes[3], linenr, linenr })
    end)

    it("can get node with id", function()
      local b_node_children = {
        Tree.Node({ text = "b-1" }),
        Tree.Node({ text = { "b-2", "b-3" } }),
      }

      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }, b_node_children),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        get_node_id = function(node)
          return type(node.text) == "table" and table.concat(node.text, "-") or node.text
        end,
      })

      tree:render()

      eq({ tree:get_node("b") }, { nodes[2], 2, 2 })

      tree:get_node("b"):expand()
      tree:render()

      eq({ tree:get_node("b-2-b-3") }, { b_node_children[2], 4, 5 })
    end)

    it("can get node on linenr", function()
      local b_node_children = {
        Tree.Node({ id = "b-1-b-2", text = { "b-1", "b-2" } }),
      }

      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }, b_node_children),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
      })

      tree:render()

      eq({ tree:get_node(1) }, { nodes[1], 1, 1 })

      tree:get_node(2):expand()
      tree:render()

      eq({ tree:get_node(3) }, { b_node_children[1], 3, 4 })
      eq({ tree:get_node(4) }, { b_node_children[1], 3, 4 })
    end)

    it("skips height-0 nodes on the cold-path linenr lookup", function()
      -- `prepare_node` returning nil makes a node render nothing (height 0),
      -- but it stays in the visible chain. The single-walk cold path (used for
      -- the first lookup after a render, before the memoized table is built)
      -- must step over such nodes instead of resolving to them.
      local nodes = {
        Tree.Node({ id = "a", text = "a" }),
        Tree.Node({ id = "b", text = "b" }),
        Tree.Node({ id = "c", text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        prepare_node = function(node)
          if node.text == "b" then
            return nil
          end
          return node.text
        end,
      })

      tree:render()

      -- buffer renders as { "a", "c" }; line 2 is "c", not the hidden "b".
      -- This first lookup exercises the cold path (memoized table not yet built).
      eq({ tree:get_node(2) }, { nodes[3], 2, 2 })

      -- re-render to reset the cold path, then check line 1 resolves to "a"
      tree:render()
      eq({ tree:get_node(1) }, { nodes[1], 1, 1 })
    end)

    it("returns a height-0 node without a linenr on the cold-path by-id lookup", function()
      local nodes = {
        Tree.Node({ id = "a", text = "a" }),
        Tree.Node({ id = "b", text = "b" }),
        Tree.Node({ id = "c", text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          if node.text == "b" then
            return nil
          end
          return node.text
        end,
      })

      tree:render()

      -- "b" is in the visible chain but renders nothing (height 0). The first
      -- by-id lookup exercises the cold path (memoized table not yet built); it
      -- must not resolve "b" to a (backwards) line range.
      local node, linenr_start, linenr_end = tree:get_node("b")
      eq(node, nodes[2])
      eq(linenr_start, nil)
      eq(linenr_end, nil)
    end)

    it("returns nil for a linenr before the first render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "x" }),
        },
      })

      eq(tree:get_node(1), nil)
    end)

    it("returns a node without a linenr when it is hidden in a collapsed subtree", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
          }),
        },
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:render()

      -- "a" is collapsed, so "a-1" is not visible
      local node, linenr_start, linenr_end = tree:get_node("a-1")
      h.neq(node, nil)
      eq(linenr_start, nil)
      eq(linenr_end, nil)
    end)

    it("reports updated line numbers after a mutation shifts a node", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:render()

      local _, b_start = tree:get_node("b")
      eq(b_start, 2)

      tree:get_node("a"):expand()
      tree:render()

      -- "b" has shifted down by the newly-visible "a-1"
      local _, b_start_after, b_end_after = tree:get_node("b")
      eq(b_start_after, 3)
      eq(b_end_after, 3)

      -- lookup by the new line number resolves to "b" too
      eq((tree:get_node(3)):get_id(), "b")
    end)

    it("returns nil for an unknown node id after render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }),
        },
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:render()

      eq(tree:get_node("nonexistent"), nil)
    end)

    it("returns nil for a linenr above the rendered region on the cold path", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "NuiTreeTest",
        "",
        "",
      })

      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }),
        },
        get_node_id = function(node)
          return node.text
        end,
      })

      -- the tree starts at line 3; a line above it has no node. This first lookup
      -- exercises the cold path (memoized table not yet built).
      tree:render(3)

      eq(tree:get_node(1), nil)
    end)

    it("returns a hidden node without a linenr on the warm-cache by-id lookup", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
          }),
        },
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:render()

      -- two lookups warm the memoized table (the cold path is exercised until then)
      tree:get_node("a")
      tree:get_node("a")

      -- "a" is collapsed, so "a-1" occupies no line. The warm path must report it
      -- as an existing-but-not-visible node, mirroring the cold path.
      local node, linenr_start, linenr_end = tree:get_node("a-1")
      h.neq(node, nil)
      eq(linenr_start, nil)
      eq(linenr_end, nil)
    end)

    it("returns nil for a linenr with no node on the warm-cache lookup", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }),
        },
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:render()

      -- two lookups warm the memoized table
      tree:get_node(1)
      tree:get_node(1)

      -- a line past the rendered region has no node
      eq(tree:get_node(99), nil)
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
        bufnr = bufnr,
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
        bufnr = bufnr,
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

  describe("method :add_node", function()
    it("throw if invalid parent_id", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "x" }),
        },
      })

      local ok, err = pcall(tree.add_node, tree, Tree.Node({ text = "y" }), "invalid_parent_id")
      eq(ok, false)
      eq(type(err), "string")
    end)

    it("can add node at root", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "x" }),
        },
      })

      tree:add_node(Tree.Node({ text = "y" }))

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  x",
        "  y",
      })

      tree:add_node(Tree.Node({ text = "z" }))

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  x",
        "  y",
        "  z",
      })
    end)

    it("can add node under parent node", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }, {
          Tree.Node({ text = "b-1" }),
        }),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:add_node(Tree.Node({ text = "b-2" }), "b")

      tree:get_node("b"):expand()

      tree:add_node(Tree.Node({ text = "c-1" }), "c")

      tree:get_node("c"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        " b",
        "    b-1",
        "    b-2",
        " c",
        "    c-1",
      })
    end)

    it("can add a child to an expanded node with a following sibling after render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:get_node("a"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "b",
      })

      tree:add_node(Tree.Node({ text = "a-2" }), "a")

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "  a-2",
        "b",
      })

      -- a subsequent full re-render must not lose the following sibling
      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "  a-2",
        "b",
      })
    end)

    it("can add a child to a collapsed node with existing children, then expand", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "b",
      })

      -- "a" is collapsed while the child is added
      tree:add_node(Tree.Node({ text = "a-2" }), "a")

      tree:get_node("a"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "  a-2",
        "b",
      })
    end)

    it("renders a root node added together with another change in one render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:render()

      -- one other change (expand) queued, plus a root-level add, then a single render
      tree:get_node("a"):expand()
      tree:add_node(Tree.Node({ text = "c" }))

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "b",
        "c",
      })
    end)

    it("can add an already-expanded root node with children after render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
      })

      local c = Tree.Node({ text = "c" }, {
        Tree.Node({ text = "c-1" }),
      })
      c:expand()

      tree:add_node(c)

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "c",
        "  c-1",
      })
    end)

    it("appends a root node after an expanded sibling's visible subtree", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
          }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:get_node("a"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
      })

      -- the last root ("a") is expanded, so the new root must be linked after
      -- "a"'s last visible descendant ("a-1"), not directly after "a"
      tree:add_node(Tree.Node({ text = "c" }))

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "c",
      })
    end)
  end)

  describe("method :set_nodes", function()
    it("throw if invalid parent_id", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "x" }),
        },
      })

      local ok, err = pcall(tree.set_nodes, tree, {}, "invalid_parent_id")
      eq(ok, false)
      eq(type(err), "string")
    end)

    it("can set nodes at root", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "x" }),
        },
      })

      tree:set_nodes({
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }),
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        "  b",
      })

      tree:set_nodes({
        Tree.Node({ text = "c" }),
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
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
        bufnr = bufnr,
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

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        " b",
        "    b-2",
        " c",
        "    c-1",
        "    c-2",
      })
    end)

    it("can replace children of an expanded node after render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
            Tree.Node({ text = "a-2" }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:get_node("a"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "  a-2",
        "b",
      })

      tree:set_nodes({
        Tree.Node({ text = "a-3" }),
      }, "a")

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-3",
        "b",
      })

      -- a subsequent full re-render must stay consistent
      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-3",
        "b",
      })
    end)

    it("can replace children of a collapsed node, then expand", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "b",
      })

      -- "a" is collapsed while its children are replaced
      tree:set_nodes({
        Tree.Node({ text = "a-2" }),
        Tree.Node({ text = "a-3" }),
      }, "a")

      tree:get_node("a"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-2",
        "  a-3",
        "b",
      })
    end)

    it("detaches replaced nodes so a stale reference cannot corrupt the tree", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }, {
              Tree.Node({ text = "a-1-x" }),
            }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:get_node("a"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "b",
      })

      -- hold a reference to a node that is about to be replaced
      local stale = tree:get_node("a-1")

      tree:set_nodes({
        Tree.Node({ text = "a-2" }),
      }, "a")

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-2",
        "b",
      })

      -- the replaced node is detached: expand() must not poke the live tree
      eq(stale._tree, nil)
      eq(stale._prev, nil)
      eq(stale._next, nil)

      stale:expand()

      tree:render()

      -- the stale node must not have spliced any phantom lines into the buffer
      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-2",
        "b",
      })
    end)
  end)

  describe("method :remove_node", function()
    it("throws if node_id is invalid", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "x" }),
        },
      })

      local ok, err = pcall(tree.remove_node, tree, "invalid_node_id")
      eq(ok, false)
      eq(type(err), "string")
      h.neq(string.find(err, "invalid node_id", 1, true), nil)
    end)

    it("detaches the removed node from the tree", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }, {
          Tree.Node({ text = "b-1" }),
        }),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:get_node("b"):expand()
      tree:render()

      local removed = tree:remove_node("b")

      -- the tree-chain references are cleared so the node can be garbage collected
      eq(removed._tree, nil)
      eq(removed._prev, nil)
      eq(removed._next, nil)

      -- expand()/collapse() on a detached node is a no-op instead of poking the tree
      removed._is_expanded = false
      eq(removed:expand(), true)

      -- the tree itself renders correctly without the removed node
      tree:render()
      h.assert_buf_lines(tree.bufnr, {
        "  a",
        "  c",
      })
    end)

    it("can remove node w/o parent", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }, {
          Tree.Node({ text = "b-1" }),
        }),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:remove_node("a")

      tree:get_node("b"):expand()

      tree:render()

      eq(
        vim.tbl_map(function(node)
          return node:get_id()
        end, tree:get_nodes()),
        { "b", "c" }
      )

      h.assert_buf_lines(tree.bufnr, {
        " b",
        "    b-1",
        "  c",
      })
    end)

    it("can remove node w/ parent", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }, {
          Tree.Node({ text = "b-1" }),
        }),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:remove_node("b-1")

      tree:render()

      eq(tree:get_node("b"):get_child_ids(), {})

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        "  b",
        "  c",
      })
    end)

    it("removes children nodes recursively", function()
      local nodes = {
        Tree.Node({ text = "a" }, {
          Tree.Node({ text = "a-1" }, {
            Tree.Node({ text = "a-1-x" }),
          }),
        }),
      }
      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
      })
      h.neq(tree:get_node("a"), nil)
      h.neq(tree:get_node("a-1"), nil)
      h.neq(tree:get_node("a-1-x"), nil)

      tree:remove_node("a")

      eq(tree:get_node("a"), nil)
      eq(tree:get_node("a-1"), nil)
      eq(tree:get_node("a-1-x"), nil)
    end)

    it("can remove a middle node after render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }),
          Tree.Node({ text = "b" }),
          Tree.Node({ text = "c" }),
        },
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        "  b",
        "  c",
      })

      tree:remove_node("b")

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        "  c",
      })
    end)

    it("can remove the head node after render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }),
          Tree.Node({ text = "b" }),
          Tree.Node({ text = "c" }),
        },
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:render()

      tree:remove_node("a")

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  b",
        "  c",
      })
    end)

    it("can remove the tail node after render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }),
          Tree.Node({ text = "b" }),
          Tree.Node({ text = "c" }),
        },
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:render()

      tree:remove_node("c")

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        "  b",
      })

      -- a subsequent full re-render walks the chain from the head and must not
      -- resurrect the removed tail node
      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  a",
        "  b",
      })
    end)

    it("can remove an expanded node with children after render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
            Tree.Node({ text = "a-2" }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:get_node("a"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "  a-2",
        "b",
      })

      tree:remove_node("a")

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "b",
      })
    end)

    it("does not corrupt visible lines when removing a node in a collapsed subtree after render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
            Tree.Node({ text = "a-2" }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "b",
      })

      -- "a" is collapsed, so "a-1" is not visible
      tree:remove_node("a-1")

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "b",
      })
    end)
  end)

  describe("method :render", function()
    it("handles unexpected case of missing node", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
      })

      -- this should not happen normally
      tree.nodes.by_id["a"] = nil

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "  b",
        "  c",
      })
    end)

    it("skips node if o.prepare_node returns nil", function()
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }),
        Tree.Node({ text = "c" }),
      }

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          if node:get_id() == "b" then
            return nil
          end

          return node.text
        end,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "c",
      })
    end)

    it("supports param linenr_start", function()
      local b_node_children = {
        Tree.Node({ text = "b-1" }),
        Tree.Node({ text = "b-2" }),
      }
      local nodes = {
        Tree.Node({ text = "a" }),
        Tree.Node({ text = "b" }, b_node_children),
      }

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "NuiTreeTest",
        "",
        "NuiTreeTest",
      })

      local tree = Tree({
        bufnr = bufnr,
        nodes = nodes,
        get_node_id = function(node)
          return node.text
        end,
      })

      tree:render(2)

      h.assert_buf_lines(tree.bufnr, {
        "NuiTreeTest",
        "  a",
        " b",
        "NuiTreeTest",
      })

      nodes[2]:expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "NuiTreeTest",
        "  a",
        " b",
        "    b-1",
        "    b-2",
        "NuiTreeTest",
      })

      nodes[2]:collapse()

      tree:render(3)

      h.assert_buf_lines(tree.bufnr, {
        "NuiTreeTest",
        "",
        "  a",
        " b",
        "NuiTreeTest",
      })
    end)

    it("shifts rendered lines up when re-rendered at a smaller linenr_start", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "NuiTreeTest",
        "",
      })

      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return node.text
        end,
      })

      tree:render(3)

      h.assert_buf_lines(tree.bufnr, {
        "NuiTreeTest",
        "",
        "a",
        "b",
      })

      -- re-rendering higher up shifts the tree upwards, dropping the leading lines
      tree:render(1)

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "b",
      })
    end)

    it("applies multiple pending changes queued before a single render", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
          }),
          Tree.Node({ text = "b" }, {
            Tree.Node({ text = "b-1" }),
          }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "b",
      })

      -- two independent expands queued before a single render
      tree:get_node("a"):expand()
      tree:get_node("b"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "b",
        "  b-1",
      })
    end)

    it("stays consistent when a mutation boundary is computed from the warm linenr cache", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a1" }),
          }),
          Tree.Node({ text = "b" }),
          Tree.Node({ text = "c" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:get_node("a"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a1",
        "b",
        "c",
      })

      -- repeated lookups build the memoized linenr cache
      tree:get_node("b")
      tree:get_node("c")

      -- "b" is collapsed, so this add does not touch the visible layout or the cache
      tree:add_node(Tree.Node({ text = "b1" }), "b")

      -- expanding "b" now computes its boundary via the warm cache fast path
      tree:get_node("b"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a1",
        "b",
        "  b1",
        "c",
      })

      -- reported line numbers stay correct after the cache-driven mutation
      local _, c_start, c_end = tree:get_node("c")
      eq(c_start, 5)
      eq(c_end, 5)
    end)

    it("renders correctly on an incremental expand/collapse with multi-line nodes", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          local indent = string.rep("  ", node:get_depth() - 1)
          return { indent .. node.text, indent .. node.text .. " (2)" }
        end,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "a (2)",
        "b",
        "b (2)",
      })

      -- expanding inserts a 2-line node; the height math must place "b" correctly
      tree:get_node("a"):expand()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "a (2)",
        "  a-1",
        "  a-1 (2)",
        "b",
        "b (2)",
      })

      -- collapsing removes those 2 lines again
      tree:get_node("a"):collapse()

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "a (2)",
        "b",
        "b (2)",
      })
    end)

    it("keeps highlights correct after a partial redraw", function()
      -- node texts avoid Lua pattern magic chars so assert_highlight's string.find works
      local hl_group = "NuiTreeTestHl"

      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "parent" }, {
            Tree.Node({ text = "child" }),
          }),
          Tree.Node({ text = "sibling" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return Line({ Text(node.text, hl_group) })
        end,
      })

      tree:render()

      h.assert_highlight(tree.bufnr, tree.ns_id, 1, "parent", hl_group)
      h.assert_highlight(tree.bufnr, tree.ns_id, 2, "sibling", hl_group)

      -- an incremental expand inserts "child" and shifts "sibling" down by one line
      tree:get_node("parent"):expand()

      tree:render()

      h.assert_highlight(tree.bufnr, tree.ns_id, 1, "parent", hl_group)
      h.assert_highlight(tree.bufnr, tree.ns_id, 2, "child", hl_group)
      h.assert_highlight(tree.bufnr, tree.ns_id, 3, "sibling", hl_group)
    end)

    it("expanding a node hidden under a collapsed ancestor does not corrupt the tree", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }, {
              Tree.Node({ text = "a-1-x" }),
            }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "b",
      })

      -- "a" is collapsed, so "a-1" is not visible
      tree:get_node("a-1"):expand()
      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "b",
      })

      -- expanding the ancestor must reveal the whole (already-expanded) subtree
      tree:get_node("a"):expand()
      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "    a-1-x",
        "b",
      })
    end)

    it("collapsing a node hidden under a collapsed ancestor does not corrupt the tree", function()
      local tree = Tree({
        bufnr = bufnr,
        nodes = {
          Tree.Node({ text = "a" }, {
            Tree.Node({ text = "a-1" }, {
              Tree.Node({ text = "a-1-x" }),
            }),
          }),
          Tree.Node({ text = "b" }),
        },
        get_node_id = function(node)
          return node.text
        end,
        prepare_node = function(node)
          return string.rep("  ", node:get_depth() - 1) .. node.text
        end,
      })

      -- pre-expand a-1, then collapse "a" so a-1 is hidden while still expanded
      tree:get_node("a-1"):expand()
      tree:render()
      tree:get_node("a"):collapse()
      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "b",
      })

      -- collapse the hidden a-1, then reveal the subtree: a-1 must now be collapsed
      tree:get_node("a-1"):collapse()
      tree:get_node("a"):expand()
      tree:render()

      h.assert_buf_lines(tree.bufnr, {
        "a",
        "  a-1",
        "b",
      })
    end)
  end)
end)

describe("nui.tree.Node", function()
  describe("method :has_children", function()
    it("works before initialization", function()
      local node_wo_children = Tree.Node({ text = "a" })
      local node_w_children = Tree.Node({ text = "b" }, { Tree.Node({ text = "b-1" }) })

      eq(node_wo_children._initialized, false)
      eq(node_wo_children:has_children(), false)

      eq(node_w_children._initialized, false)
      eq(type(node_w_children.__children), "table")
      eq(node_w_children:has_children(), true)
    end)

    it("works after initialization", function()
      local node_wo_children = Tree.Node({ text = "a" })
      local node_w_children = Tree.Node({ text = "b" }, { Tree.Node({ text = "b-1" }) })

      Tree({
        bufnr = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win()),
        nodes = { node_wo_children, node_w_children },
      })

      eq(node_wo_children._initialized, true)
      eq(node_wo_children:has_children(), false)

      eq(node_w_children._initialized, true)
      eq(type(node_w_children.__children), "nil")
      eq(node_w_children:has_children(), true)
    end)
  end)

  describe("method :expand", function()
    it("returns true if not already expanded", function()
      local node = Tree.Node({ text = "b" }, { Tree.Node({ text = "b-1" }) })
      eq(node:is_expanded(), false)
      eq(node:expand(), true)
      eq(node:is_expanded(), true)
    end)

    it("returns false if already expanded", function()
      local node = Tree.Node({ text = "b" }, { Tree.Node({ text = "b-1" }) })
      node:expand()
      eq(node:is_expanded(), true)
      eq(node:expand(), false)
      eq(node:is_expanded(), true)
    end)

    it("does work w/ zero child", function()
      local node = Tree.Node({ text = "a" }, {})
      eq(node:is_expanded(), false)
      eq(node:expand(), true)
      eq(node:is_expanded(), true)
    end)

    it("does not work w/o children", function()
      local node = Tree.Node({ text = "a" })
      eq(node:is_expanded(), false)
      eq(node:expand(), false)
      eq(node:is_expanded(), false)
    end)
  end)

  describe("method :collapse", function()
    it("returns true if not already collapsed", function()
      local node = Tree.Node({ text = "b" }, { Tree.Node({ text = "b-1" }) })
      node:expand()
      eq(node:is_expanded(), true)
      eq(node:collapse(), true)
      eq(node:is_expanded(), false)
    end)

    it("returns false if already collapsed", function()
      local node = Tree.Node({ text = "b" }, { Tree.Node({ text = "b-1" }) })
      eq(node:is_expanded(), false)
      eq(node:collapse(), false)
      eq(node:is_expanded(), false)
    end)

    it("does not work w/o children", function()
      local node = Tree.Node({ text = "a" })
      eq(node:is_expanded(), false)
      eq(node:collapse(), false)
      eq(node:is_expanded(), false)
    end)
  end)
end)
