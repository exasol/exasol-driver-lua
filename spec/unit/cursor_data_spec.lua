---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local CursorData = require("cursor_data")
local config = require("config")
local log = require("remotelog")
local util = require("test_util")
config.configure_logging()

local create_resultset<const> = util.create_resultset
local create_batched_resultset<const> = util.create_batched_resultset
local create_fetch_result<const> = util.create_fetch_result
local RESULT_SET_HANDLE<const> = 321
local FETCH_SIZE_BYTES<const> = 1024

describe("CursorData", function()
    local websocket_stub = nil
    local connection_properties_stub = nil
    local data = nil

    local function create_cursor_data(result_set)
        return CursorData:create(connection_properties_stub, websocket_stub, result_set)
    end

    local function assert_row(expected_values)
        for column_index, value in ipairs(expected_values) do
            assert.is_same(value, data:get_column_value(column_index), "value of column " .. column_index)
        end
    end

    local function simulate_fetch(expected_start_position, result)
        websocket_stub.send_fetch = function(_self, actual_result_set_handle, actual_start_position, actual_num_bytes)
            log.debug("Simulating fetch with start pos %d", actual_start_position)
            assert.is_same(RESULT_SET_HANDLE, actual_result_set_handle, "result set handle")
            assert.is_same(expected_start_position, actual_start_position, "start position")
            assert.is_same(FETCH_SIZE_BYTES, actual_num_bytes, "fetch size")
            return result, nil
        end
    end
    local function simulate_fetch_error(err)
        websocket_stub.send_fetch = function(_self, actual_result_set_handle, actual_start_position, actual_num_bytes)
            return nil, err
        end
    end

    before_each(function()
        websocket_stub = {close = function() end}
        connection_properties_stub = {get_fetchsize_bytes = function() return FETCH_SIZE_BYTES end}
    end)

    after_each(function()
        websocket_stub = nil
        connection_properties_stub = nil
        data = nil
    end)

    describe("create()", function()
        it("fails for missing connection properties", function()
            assert.has_error(function() CursorData:create(nil, {}, {}) end, "connection_properties missing")
        end)
        it("fails for missing numRows", function()
            assert.has_error(function() CursorData:create({}, {}, {}) end, "numRows missing in result set")
        end)
        it("fails for missing numRowsInMessage", function()
            assert.has_error(function() CursorData:create({}, {}, {numRows = 5}) end,
                             "numRowsInMessage missing in result set")
        end)
        it("returns non-nil value",
           function() assert.is_not_nil(CursorData:create({}, {}, {numRows = 5, numRowsInMessage = 2})) end)
    end)

    describe("next_row()", function()
        it("advances to next row", function()
            data = create_cursor_data(create_resultset())
            data:next_row()
            assert.is_same(2, data:get_current_row())
        end)
        it("advances to next next row", function()
            data = create_cursor_data(create_resultset())
            data:next_row()
            data:next_row()
            assert.is_same(3, data:get_current_row())
        end)
    end)

    describe("get_current_row()", function()
        it("has initial value 1", function()
            data = create_cursor_data(create_resultset())
            assert.is_same(1, data:get_current_row())
        end)
        it("increments with next_row()", function()
            data = create_cursor_data(create_resultset())
            data:next_row()
            assert.is_same(2, data:get_current_row())
        end)
    end)

    describe("has_more_rows()", function()
        it("returns false for empty result set", function()
            data = create_cursor_data(create_resultset())
            assert.is_false(data:has_more_rows())
        end)
        it("returns true for non-empty result set", function()
            data = create_cursor_data(create_resultset({"c1"}, {{c1 = 1}}))
            assert.is_true(data:has_more_rows())
        end)
        it("returns false after fetching all data", function()
            data = create_cursor_data(create_resultset({"c1"}, {{c1 = 1}}))
            data:next_row()
            assert.is_false(data:has_more_rows())
        end)
    end)

    describe("get_column_value()", function()
        describe("with small result set", function()
            it("fails for empty result set", function()
                data = create_cursor_data(create_resultset({"c1"}, {}))
                assert.error_matches(function() data:get_column_value(1) end,
                                     "E%-EDL%-30: Row 1 out of bound, only 0 rows are available in current batch.*")
            end)
            it("fails for result set without column", function()
                data = create_cursor_data(create_resultset({}, {{c1 = 1}}))
                assert.error_matches(function() data:get_column_value(1) end,
                                     "E%-EDL%-29: Column index 1 out of bound, only 0 columns are available.*")
            end)
            it("fails for zero column index", function()
                data = create_cursor_data(create_resultset({"c1"}, {{c1 = 1}}))
                assert.error_matches(function() data:get_column_value(0) end,
                                     "E%-EDL%-29: Column index 0 out of bound, only 1 columns are available.*")
            end)
            it("returns first column of first row", function()
                data = create_cursor_data(create_resultset({"c1", "c2", "c3"}, {{c1 = 1, c2 = "a", c3 = true}}))
                assert.is_same(1, data:get_column_value(1))
            end)
            it("returns second column of first row", function()
                data = create_cursor_data(create_resultset({"c1", "c2", "c3"}, {{c1 = 1, c2 = "a", c3 = true}}))
                assert.is_same("a", data:get_column_value(2))
            end)
            it("returns third column of first row", function()
                data = create_cursor_data(create_resultset({"c1", "c2", "c3"}, {{c1 = 1, c2 = "a", c3 = true}}))
                assert.is_same(true, data:get_column_value(3))
            end)
            it("does not advance to next row", function()
                data = create_cursor_data(create_resultset({"c1", "c2", "c3"}, {
                    {c1 = 1, c2 = "a", c3 = true}, {c1 = 2, c2 = "b", c3 = false}
                }))
                assert.is_same(1, data:get_column_value(1))
                assert.is_same("a", data:get_column_value(2))
                assert.is_same(true, data:get_column_value(3))
            end)
            it("returns first column of second row", function()
                data = create_cursor_data(create_resultset({"c1", "c2", "c3"}, {
                    {c1 = 1, c2 = "a", c3 = true}, {c1 = 2, c2 = "b", c3 = false}
                }))
                data:next_row()
                assert.is_same(2, data:get_column_value(1))
            end)
        end)

        describe("with batches", function()
            it("fails for missing result set handle", function()
                data = create_cursor_data(create_batched_resultset({"c1", "c2", "c3"}, 0, nil))
                assert.error_matches(function() data:get_column_value(1) end,
                                     "F%-EDL%-25: Neither data nor result set handle available.*")
            end)
            it("raises error for numRows in fetch result", function()
                data = create_cursor_data(create_batched_resultset({"c1", "c2", "c3"}, 0, RESULT_SET_HANDLE))
                simulate_fetch(0, {data = {}, numRows = nil})
                assert.error(function() data:get_column_value(1) end, "missing numRows")
            end)
            it("raises error for data in fetch result", function()
                data = create_cursor_data(create_batched_resultset({"c1", "c2", "c3"}, 0, RESULT_SET_HANDLE))
                simulate_fetch(0, {numRows = 1, data = nil})
                assert.error(function() data:get_column_value(1) end, "missing data")
            end)
            it("raises error for empty data in fetch result", function()
                data = create_cursor_data(create_batched_resultset({"c1", "c2", "c3"}, 0, RESULT_SET_HANDLE))
                simulate_fetch(0, {numRows = 1, data = {}})
                assert.error_matches(function() data:get_column_value(1) end,
                                     "E%-EDL%-29: Column index 1 out of bound, only 0 columns are available")
            end)
            it("raises error for missing rows in fetch result", function()
                data = create_cursor_data(create_batched_resultset({"c1", "c2", "c3"}, 0, RESULT_SET_HANDLE))
                simulate_fetch(0, create_fetch_result({"c1", "c2", "c3"}, {}))
                assert.error_matches(function() data:get_column_value(1) end,
                                     "E%-EDL%-30: Row 1 out of bound, only 0 rows are available in current batch.*")
            end)
            it("raises error when fetch returns errror", function()
                data = create_cursor_data(create_batched_resultset({"c1", "c2", "c3"}, 0, RESULT_SET_HANDLE))
                simulate_fetch_error("mock error")
                assert.error(function() data:get_column_value(1) end,
                             "E-EDL-26: Error fetching result data for handle 321 with start position 0 and fetch size 'missing value' bytes: 'mock error'")
            end)

            it("returns data for single row", function()
                data = create_cursor_data(create_batched_resultset({"c1", "c2", "c3"}, 0, RESULT_SET_HANDLE))
                simulate_fetch(0, create_fetch_result({"c1", "c2", "c3"}, {{c1 = 1, c2 = "a", c3 = true}}))
                assert_row({1, "a", true})
            end)
            it("returns data from second row #only", function()
                data = create_cursor_data(create_batched_resultset({"c1", "c2", "c3"}, 2, RESULT_SET_HANDLE))
                simulate_fetch(0, create_fetch_result({"c1", "c2", "c3"},
                                                      {{c1 = 1, c2 = "a", c3 = true}, {c1 = 2, c2 = "b", c3 = false}}))
                data:next_row()
                assert_row({2, "b", false})
            end)
            it("fetches second batch", function()
                data = create_cursor_data(create_batched_resultset({"c1", "c2", "c3"}, 2, RESULT_SET_HANDLE))
                simulate_fetch(0, create_fetch_result({"c1", "c2", "c3"}, {{c1 = 1, c2 = "a", c3 = true}}))
                data:next_row()
                simulate_fetch(1, create_fetch_result({"c1", "c2", "c3"}, {{c1 = 2, c2 = "b", c3 = false}}))
                assert.is_same(2, data:get_column_value(1))
            end)
            it("first batch has two rows, fetch second batch", function()
                data = create_cursor_data(create_batched_resultset({"c1", "c2", "c3"}, 3, RESULT_SET_HANDLE))
                simulate_fetch(0, create_fetch_result({"c1", "c2", "c3"},
                                                      {{c1 = 1, c2 = "a", c3 = true}, {c1 = 2, c2 = "b", c3 = false}}))
                assert_row({1, "a", true})
                data:next_row()
                assert_row({2, "b", false})
                data:next_row()
                simulate_fetch(1, create_fetch_result({"c1", "c2", "c3"}, {{c1 = 3, c2 = "c", c3 = 3.14}}))
                assert_row({3, "c", 3.14})
            end)
        end)
    end)

end)
