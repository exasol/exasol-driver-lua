---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local cursor = require("cursor")
local config = require("config")
config.configure_logging()

local SESSION_ID = 12345

describe("Cursor", function()
    local websocket_stub = nil

    before_each(function() websocket_stub = {} end)

    local function create_cursor(result_set) return cursor:create(websocket_stub, SESSION_ID, result_set) end

    describe("fetch()", function()
        it("throws error when cursor is closed", function()
            local cur = create_cursor({})
            cur:close()
            assert.has_error(function() cur:fetch() end,
                             "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
        end)

        it("returns nil when result set is empty", function()
            local cur = create_cursor({numRows = 0})
            assert.is_nil(cur:fetch())
        end)

        it("returns first row when result set is not empty", function()
            local cur = create_cursor({numRows = 1, numColumns = 1, data = {{"val"}}})
            assert.is_same({"val"}, cur:fetch())
            assert.is_nil(cur:fetch())
        end)

        it("returns multiple rows", function()
            local cur = create_cursor({numRows = 2, numColumns = 1, data = {{"a", "b"}}})
            assert.is_same({"a"}, cur:fetch())
            assert.is_same({"b"}, cur:fetch())
            assert.is_nil(cur:fetch())
        end)

        it("returns multiple columns", function()
            local cur = create_cursor({numRows = 1, numColumns = 3, data = {{1}, {"a"}, {true}}})
            assert.is_same({1, "a", true}, cur:fetch())
            assert.is_nil(cur:fetch())
        end)
    end)

    describe("close()", function()
        it("can be called twice", function()
            local cur = create_cursor({numRows = 0})
            cur:close()
            cur:close()
        end)
    end)
end)
