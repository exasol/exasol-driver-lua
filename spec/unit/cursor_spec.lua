---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local cursor = require("cursor")
local config = require("config")
config.configure_logging()

local SESSION_ID<const> = 12345

local function create_resultset(column_names, rows)
    local columns = {}
    local data = {}
    for column_index, column_name in ipairs(column_names) do
        table.insert(columns, {name = column_name})
        data[column_index] = {}
        for row_index, row in ipairs(rows) do
            local value = row[column_name]
            if value == nil then error("No value for row " .. row_index .. " column " .. column_name) end
            table.insert(data[column_index], value)
        end
    end
    return {numRows = #rows, numRowsInMessage = #rows, numColumns = #columns, columns = columns, data = data}
end

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
            local cur = create_cursor(create_resultset({}, {}))
            cur:close()
            assert.has_error(function() cur:fetch() end,
                             "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
        end)

        it("returns nil when result set is empty", function()
            local cur = create_cursor(create_resultset({}, {}))
            assert.is_nil(cur:fetch())
        end)

        it("returns first row when result set is not empty", function()
            local cur = create_cursor(create_resultset({"col1"}, {{col1 = "val"}}))
            assert.is_same({"val"}, cur:fetch())
            assert.is_nil(cur:fetch())
        end)

        it("re-uses table passed as argument", function()
            local cur = create_cursor(create_resultset({"col1"}, {{col1 = "val"}}))
            local data = {}
            local row = cur:fetch(data)
            assert.is_equal(data, row)
            assert.is_same({"val"}, data)
        end)

        it("returns new table each time when no argument specified", function()
            local cur = create_cursor(create_resultset({"col1"}, {{col1 = "a"}, {col1 = "b"}}))
            local row1 = cur:fetch()
            local row2 = cur:fetch()
            assert.is_not_same(row1, row2)
        end)

        it("returns new table each time when nil argument specified", function()
            local cur = create_cursor(create_resultset({"col1"}, {{col1 = "a"}, {col1 = "b"}}))
            local row1 = cur:fetch(nil)
            local row2 = cur:fetch(nil)
            assert.is_not_same(row1, row2)
        end)

        it("returns multiple rows", function()
            local cur = create_cursor(create_resultset({"col1"}, {{col1 = "a"}, {col1 = "b"}}))
            assert.is_same({"a"}, cur:fetch())
            assert.is_same({"b"}, cur:fetch())
            assert.is_nil(cur:fetch())
        end)

        it("returns multiple columns", function()
            local cur = create_cursor(create_resultset({"c1", "c2", "c3"}, {{c1 = 1, c2 = "a", c3 = true}}))
            assert.is_same({1, "a", true}, cur:fetch())
            assert.is_nil(cur:fetch())
        end)

        it("returns table with alphanumeric indices", function()
            local cur = create_cursor(create_resultset({"id", "name", "active"}, {
                {id = 1, name = "a", active = true}, {id = 2, name = "b", active = false}
            }))
            assert.is_same({id = 1, name = "a", active = true}, cur:fetch({}, "a"))
            assert.is_same({id = 2, name = "b", active = false}, cur:fetch({}, "a"))
            assert.is_nil(cur:fetch())
        end)

        it("returns table with numeric indices", function()
            local cur = create_cursor(create_resultset({"id", "name", "active"}, {
                {id = 1, name = "a", active = true}, {id = 2, name = "b", active = false}
            }))
            assert.is_same({1, "a", true}, cur:fetch({}, "n"))
            assert.is_same({2, "b", false}, cur:fetch({}, "n"))
            assert.is_nil(cur:fetch())
        end)

        it("uses numeric indices by default", function()
            local cur = create_cursor(create_resultset({"id", "name", "active"}, {
                {id = 1, name = "a", active = true}, {id = 2, name = "b", active = false}
            }))
            assert.is_same({1, "a", true}, cur:fetch({}))
            assert.is_same({2, "b", false}, cur:fetch({}))
            assert.is_nil(cur:fetch())
        end)

        it("allows mixing numeric and alphanumeric indices", function()
            local cur = create_cursor(create_resultset({"id", "name", "active"}, {
                {id = 1, name = "a", active = true}, {id = 2, name = "b", active = false}
            }))
            assert.is_same({1, "a", true}, cur:fetch({}, "n"))
            assert.is_same({id = 2, name = "b", active = false}, cur:fetch({}, "a"))
            assert.is_nil(cur:fetch())
        end)

        it("closes the cursor if there are no more rows left", function()
            local cur = create_cursor(create_resultset({"id"}, {{id = 1}, {id = 2}}))
            assert.is_not_nil(cur:fetch())
            assert.is_not_nil(cur:fetch())
            assert.is_nil(cur:fetch())
            assert.has_error(function() cur:fetch() end,
                             "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
        end)
    end)

    describe("close()", function()
        it("can be called twice", function()
            local cur = create_cursor(create_resultset({}, {}))
            cur:close()
            cur:close()
        end)

        it("returns true when called once", function()
            local cur = create_cursor(create_resultset({}, {}))
            assert.is_true(cur:close())
        end)

        it("returns fallse when called a second time", function()
            local cur = create_cursor(create_resultset({}, {}))
            cur:close()
            assert.is_false(cur:close())
        end)

        it("does not close the websocket", function()
            local cur = create_cursor(create_resultset({}, {}))
            cur:close()
            assert.stub(websocket_mock.close).was.not_called()
        end)
    end)
end)
