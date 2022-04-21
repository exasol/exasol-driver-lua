---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local connection = require("connection")
local ConnectionProperties = require("connection_properties")
local config = require("config")
config.configure_logging()

local SESSION_ID = 12345

local execute_result = {}
local execute_error = nil
local set_attribute_error = nil

local websocket_stub = {
    send_execute = function() return execute_result, execute_error end,
    send_set_attribute = function() return set_attribute_error end,
    send_disconnect = function() end,
    close = function() end
}

local function simulate_result(num_results, results)
    execute_result = {numResults = num_results, results = results}
    execute_error = nil
end

local function simulate_result_set(result_set)
    simulate_result(1, {{resultType = "resultSet", resultSet = result_set}})
    execute_error = nil
end

local function simulate_error(err)
    execute_result = nil
    execute_error = err
end

describe("Connection", function()
    local conn = nil
    local websocket_mock = nil

    before_each(function()
        websocket_mock = mock(websocket_stub, false)
        local connection_properties = ConnectionProperties:create()
        conn = connection:create(connection_properties, websocket_mock, SESSION_ID)
        execute_result = {}
        execute_error = nil
        set_attribute_error = nil
    end)

    after_each(function()
        conn:close()
        conn = nil
    end)

    describe("execute()", function()
        it("raises error when no results available", function()
            simulate_result(0, {})
            assert.has_error(function() conn:execute("statement") end,
                             [[E-EDL-7: Got no results for statement 'statement'

Mitigations:

* This is an internal software error. Please report it via the project's ticket tracker.]])
        end)

        it("returns error if more than one results available", function()
            simulate_result(2, {})
            local cursor, err = conn:execute("statement")
            assert.is_nil(cursor)
            assert.is_same([[E-EDL-8: Got 2 results for statement 'statement' but at most one is supported

Mitigations:

* Use only statements that return a single result]], tostring(err))
        end)

        it("raises error for unknown result type", function()
            simulate_result(1, {{resultType = "unknown"}})
            assert.has_error(function() conn:execute("statement") end, [[E-EDL-9: Got unexpected result type 'unknown'

Mitigations:

* This is an internal software error. Please report it via the project's ticket tracker.]])
        end)

        it("returns a cursor with results", function()
            simulate_result_set({numRows = 1, numRowsInMessage = 1, numColumns = 1, columns = {{}}, data = {{1}}})
            local cursor = assert(conn:execute("statement"))
            assert.is_same({1}, cursor:fetch())
            assert.is_nil(cursor:fetch())
        end)

        it("returns an error if execution returned an error", function()
            simulate_error("mock error")
            local cursor, err = conn:execute("statement")
            assert.is_nil(cursor)
            assert.is_same("E-EDL-6: Error executing statement 'statement': mock error", tostring(err))
        end)

        it("returns a cursor with multiple rows", function()
            simulate_result_set({numRows = 3, numRowsInMessage = 3, numColumns = 1, columns = {{}}, data = {{1, 2, 3}}})
            local cursor = assert(conn:execute("statement"))
            assert.is_same({1}, cursor:fetch())
            assert.is_same({2}, cursor:fetch())
            assert.is_same({3}, cursor:fetch())
            assert.is_nil(cursor:fetch())
        end)

        it("returns a cursor with multiple columns", function()
            simulate_result_set({
                numRows = 1,
                numRowsInMessage = 1,
                numColumns = 3,
                columns = {{}, {}, {}},
                data = {{1}, {2}, {3}}
            })
            local cursor = assert(conn:execute("statement"))
            assert.is_same({1, 2, 3}, cursor:fetch())
            assert.is_nil(cursor:fetch())
        end)

        it("raises error when connection is closed", function()
            conn:close()
            assert.has_error(function() conn:execute("statement") end,
                             "E-EDL-12: Connection already closed when trying to call 'execute'")
        end)
    end)

    describe("commit()", function()
        it("raises error when connection is closed", function()
            conn:close()
            assert.has_error(function() conn:commit() end,
                             "E-EDL-12: Connection already closed when trying to call 'commit'")
        end)
    end)

    describe("rollback()", function()
        it("raises error when connection is closed", function()
            conn:close()
            assert.has_error(function() conn:rollback() end,
                             "E-EDL-12: Connection already closed when trying to call 'rollback'")
        end)
    end)

    describe("setautocommit()", function()
        it("raises error when connection is closed", function()
            conn:close()
            assert.has_error(function() conn:setautocommit(true) end,
                             "E-EDL-12: Connection already closed when trying to call 'setautocommit'")
        end)

        it("returns true when operation was successful", function()
            set_attribute_error = nil
            assert.is_true(conn:setautocommit(true))
        end)

        it("returns falses when operation failed", function()
            set_attribute_error = "simulated error"
            assert.is_false(conn:setautocommit(true))
        end)

        describe("sends setAttribute command with", function()
            local function assert_autocommit_attribute_set(value)
                conn:setautocommit(value)
                assert.stub(websocket_mock.send_set_attribute).was.called_with(match.is_table(), "autocommit", value)
            end

            it("value true", function() assert_autocommit_attribute_set(true) end)

            it("value false", function() assert_autocommit_attribute_set(false) end)
        end)
    end)

    describe("close()", function()
        it("closes the websocket", function()
            websocket_mock.close:clear()
            conn:close()
            assert.stub(websocket_mock.close).was.called()
        end)

        it("closes the websocket only once", function()
            conn:close()
            websocket_mock.close:clear()
            conn:close()
            assert.stub(websocket_mock.close).was.not_called()
        end)
    end)
end)
