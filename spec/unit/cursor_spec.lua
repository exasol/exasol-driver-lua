---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local cursor = require("cursor")
local config = require("config")
config.configure_logging()

local SESSION_ID<const> = 12345
local DEFAULT_RESULT_SET<const> = {
    numRows = 2,
    numColumns = 3,
    columns = {{name = "id"}, {name = "name"}, {name = "active"}},
    data = {{1, 2}, {"a", "b"}, {true, false}}
}

describe("Cursor", function()
    local websocket_stub = nil
    local websocket_mock = nil

    before_each(function()
        websocket_stub = {close = function() end}
        websocket_mock = mock(websocket_stub, false)
    end)

    local function create_cursor(result_set) return cursor:create(websocket_mock, SESSION_ID, result_set) end

    describe("create()", function()
        it("throws error for inconsistent column count", function()
            assert.has_error(function() create_cursor({numColumns = 2, columns = {}}) end,
                             [[E-EDL-24: Result set reports 2 but only 0 columns are available

Mitigations:

* This is an internal software error. Please report it via the project's ticket tracker.]])
        end)
    end)

    describe("fetch()", function()
        it("throws error when cursor is closed", function()
            local cur = create_cursor({numColumns = 0, columns = {}})
            cur:close()
            assert.has_error(function() cur:fetch() end,
                             "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
        end)

        it("returns nil when result set is empty", function()
            local cur = create_cursor({numRows = 0, numColumns = 0, columns = {}})
            assert.is_nil(cur:fetch())
        end)

        it("returns first row when result set is not empty", function()
            local cur = create_cursor({numRows = 1, numColumns = 1, columns = {{}}, data = {{"val"}}})
            assert.is_same({"val"}, cur:fetch())
            assert.is_nil(cur:fetch())
        end)

        it("re-uses table passed as argument", function()
            local cur = create_cursor({numRows = 1, numColumns = 1, columns = {{}}, data = {{"val"}}})
            local data = {}
            local row = cur:fetch(data)
            assert.is_equal(data, row)
            assert.is_same({"val"}, data)
        end)

        it("returns new table each time when no argument specified", function()
            local cur = create_cursor({numRows = 2, numColumns = 1, columns = {{}}, data = {{"a", "b"}}})
            local row1 = cur:fetch()
            local row2 = cur:fetch()
            assert.is_not_same(row1, row2)
        end)

        it("returns new table each time when nil argument specified", function()
            local cur = create_cursor({numRows = 2, numColumns = 1, columns = {{}}, data = {{"a", "b"}}})
            local row1 = cur:fetch(nil)
            local row2 = cur:fetch(nil)
            assert.is_not_same(row1, row2)
        end)

        it("returns multiple rows", function()
            local cur = create_cursor({numRows = 2, numColumns = 1, columns = {{}}, data = {{"a", "b"}}})
            assert.is_same({"a"}, cur:fetch())
            assert.is_same({"b"}, cur:fetch())
            assert.is_nil(cur:fetch())
        end)

        it("returns multiple columns", function()
            local cur =
                    create_cursor({numRows = 1, numColumns = 3, columns = {{}, {}, {}}, data = {{1}, {"a"}, {true}}})
            assert.is_same({1, "a", true}, cur:fetch())
            assert.is_nil(cur:fetch())
        end)

        it("returns table with alphanumeric indices", function()
            local cur = create_cursor(DEFAULT_RESULT_SET)
            assert.is_same({id = 1, name = "a", active = true}, cur:fetch({}, "a"))
            assert.is_same({id = 2, name = "b", active = false}, cur:fetch({}, "a"))
            assert.is_nil(cur:fetch())
        end)

        it("returns table with numeric indices", function()
            local cur = create_cursor(DEFAULT_RESULT_SET)
            assert.is_same({1, "a", true}, cur:fetch({}, "n"))
            assert.is_same({2, "b", false}, cur:fetch({}, "n"))
            assert.is_nil(cur:fetch())
        end)

        it("uses numeric indices by default", function()
            local cur = create_cursor(DEFAULT_RESULT_SET)
            assert.is_same({1, "a", true}, cur:fetch({}))
            assert.is_same({2, "b", false}, cur:fetch({}))
            assert.is_nil(cur:fetch())
        end)

        it("allows mixing numeric and alphanumeric indices", function()
            local cur = create_cursor(DEFAULT_RESULT_SET)
            assert.is_same({1, "a", true}, cur:fetch({}, "n"))
            assert.is_same({id = 2, name = "b", active = false}, cur:fetch({}, "a"))
            assert.is_nil(cur:fetch())
        end)
    end)

    describe("close()", function()
        it("can be called twice", function()
            local cur = create_cursor({numRows = 0, numColumns = 0, columns = {}})
            cur:close()
            cur:close()
        end)

        it("does not close the websocket", function()
            local cur = create_cursor({numRows = 0, numColumns = 0, columns = {}})
            cur:close()
            assert.stub(websocket_mock.close).was.not_called()
        end)
    end)
end)
