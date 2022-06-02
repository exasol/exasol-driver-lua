require("busted.runner")()
local cursor = require("luasql.exasol.Cursor")
local config = require("config")
local ConnectionProperties = require("luasql.exasol.ConnectionProperties")
local resultstub = require("resultstub")
config.configure_logging()

local create_resultset<const> = resultstub.create_resultset
local SESSION_ID<const> = 1730798808850104320
local RESULT_SET_HANDLE<const> = 1730798808850104321

describe("Cursor", function()
    local websocket_stub = nil
    local websocket_mock = nil

    before_each(function()
        websocket_stub = {
            close = function()
            end,
            send_close_result_set = function()
            end
        }
        websocket_mock = mock(websocket_stub, false)
    end)

    local function create_cursor(result_set)
        local connection_properties = ConnectionProperties:create()
        return cursor:create(connection_properties, websocket_mock, SESSION_ID, result_set)
    end

    describe("create()", function()
        it("raises error for inconsistent column count", function()
            assert.has_error(function()
                create_cursor({numColumns = 2, columns = {}})
            end, [[E-EDL-24: Result set reports 2 but only 0 columns are available

Mitigations:

* This is an internal software error. Please report it via the project's ticket tracker.]])
        end)
    end)

    describe("fetch()", function()
        it("raises error when cursor is closed", function()
            local cur = create_cursor(create_resultset({}, {}))
            cur:close()
            assert.has_error(function()
                cur:fetch()
            end, "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
        end)

        it("returns nil when result set is empty", function()
            local cur = create_cursor(create_resultset({}, {}))
            assert.is_nil(cur:fetch())
        end)

        it("returns first row when result set is not empty [utest -> dsn~luasql-cursor-fetch~0]", function()
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
            assert.has_error(function()
                cur:fetch()
            end, "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
        end)
    end)

    -- [utest -> dsn~luasql-cursor-getcoltypes~0]
    describe("getcoltypes()", function()
        it("returns empty list when no columns available", function()
            local cur = create_cursor(resultstub.create_empty_resultset_with_columns({}))
            assert.is_same({}, cur:getcoltypes())
        end)

        it("returns type of single column", function()
            local cur = create_cursor(resultstub.create_empty_resultset_with_columns({{dataType = {type = "type1"}}}))
            assert.is_same({"type1"}, cur:getcoltypes())
        end)

        it("returns types of multiple columns", function()
            local cur = create_cursor(resultstub.create_empty_resultset_with_columns({
                {dataType = {type = "type1"}}, {dataType = {type = "Type_2"}}, {dataType = {type = "type 3"}}
            }))
            assert.is_same({"type1", "Type_2", "type 3"}, cur:getcoltypes())
        end)

        it("skips column with missing dataType field", function()
            local cur = create_cursor(resultstub.create_empty_resultset_with_columns({
                {dataType = {type = "type1"}}, {missing_dataType = {}}, {dataType = {type = "type 3"}}
            }))
            assert.is_same({"type1", "type 3"}, cur:getcoltypes())
        end)

        it("skips column with missing type field", function()
            local cur = create_cursor(resultstub.create_empty_resultset_with_columns({
                {dataType = {type = "type1"}}, {dataType = {}}, {dataType = {type = "type 3"}}
            }))
            assert.is_same({"type1", "type 3"}, cur:getcoltypes())
        end)
    end)

    -- [utest -> dsn~luasql-cursor-getcolnames~0]
    describe("getcolnames()", function()
        it("returns empty list when no columns available", function()
            local cur = create_cursor(create_resultset({}))
            assert.is_same({}, cur:getcolnames())
        end)

        it("returns name of a single column", function()
            local cur = create_cursor(create_resultset({"Col1"}))
            assert.is_same({"Col1"}, cur:getcolnames())
        end)

        it("returns name of a multiple columns", function()
            local cur = create_cursor(create_resultset({"Col1", "col_2", "col 3"}))
            assert.is_same({"Col1", "col_2", "col 3"}, cur:getcolnames())
        end)

        it("skips missing column names", function()
            local cur = create_cursor(resultstub.create_empty_resultset_with_columns({
                {name = "Col1"}, {wrong_name = "wrong"}, {name = "col 3"}
            }))
            assert.is_same({"Col1", "col 3"}, cur:getcolnames())
        end)
    end)

    describe("close()", function()
        it("returns true when called once", function()
            local cur = create_cursor(create_resultset({}, {}))
            assert.is_true(cur:close())
        end)

        it("returns false when called a second time", function()
            local cur = create_cursor(create_resultset({}, {}))
            cur:close()
            assert.is_false(cur:close())
        end)

        it("does not close the websocket", function()
            local cur = create_cursor(create_resultset({}, {}))
            cur:close()
            assert.stub(websocket_mock.close).was.not_called()
        end)

        it("raises error when closing the result set handle fails", function()
            local cur = create_cursor(resultstub.create_batched_resultset({}, 0, RESULT_SET_HANDLE))
            websocket_stub.send_close_result_set = function()
                return "mock error"
            end
            assert.error(function()
                cur:close()
            end, "E-EDL-28: Failed to close result set 1730798808850104321: 'mock error'")
        end)

        it("returns true when closing the result set handle succeeds", function()
            local cur = create_cursor(resultstub.create_batched_resultset({}, 0, RESULT_SET_HANDLE))
            websocket_stub.send_close_result_set = function()
                return nil
            end
            assert.is_true(cur:close())
        end)

        it("closes the result set handle", function()
            local cur = create_cursor(resultstub.create_batched_resultset({}, 0, RESULT_SET_HANDLE))
            cur:close()
            assert.stub(websocket_mock.send_close_result_set).was.called_with(match.is_table(), RESULT_SET_HANDLE)
        end)
    end)
end)
