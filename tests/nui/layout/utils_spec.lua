pcall(require, "luacov")

local utils = require("nui.layout.utils")
local h = require("tests.nui")

local eq = h.eq

describe("nui.layout", function()
  describe("utils", function()
    describe("parse_relative", function()
      local fallback_winid = 17

      it("works for type=buf", function()
        local relative = {
          type = "buf",
          position = { row = 2, col = 4 },
          winid = 42,
        }

        local result = utils.parse_relative(relative, fallback_winid)

        eq(result, {
          relative = "win",
          win = relative.winid,
          bufpos = {
            relative.position.row,
            relative.position.col,
          },
        })
      end)

      it("works for type=cursor", function()
        local relative = {
          type = "cursor",
          winid = 42,
        }

        local result = utils.parse_relative(relative, fallback_winid)

        eq(result, {
          relative = relative.type,
          win = relative.winid,
        })
      end)

      it("works for type=editor", function()
        local relative = {
          type = "editor",
          winid = 42,
        }

        local result = utils.parse_relative(relative, fallback_winid)

        eq(result, {
          relative = relative.type,
          win = relative.winid,
        })
      end)

      it("works for type=win", function()
        local relative = {
          type = "win",
          winid = 42,
        }

        local result = utils.parse_relative(relative, fallback_winid)

        eq(result, {
          relative = relative.type,
          win = relative.winid,
        })
      end)

      it("uses fallback_winid if relative.winid is nil", function()
        local relative = {
          type = "win",
        }

        local result = utils.parse_relative(relative, fallback_winid)

        eq(result, {
          relative = relative.type,
          win = fallback_winid,
        })
      end)
    end)
  end)
end)
