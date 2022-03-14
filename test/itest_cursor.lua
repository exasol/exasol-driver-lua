local luaunit = require("luaunit")
local config = require("config")
local assertions = require("assertions")

TestCursor = {}

function TestCursor:setUp()
    self.connection = config.create_connection()
    luaunit.assertNotNil(self.connection)
    self.assertions = assertions:new(self.connection)
end

function TestCursor:tearDown()
    self.connection:close()
    self.connection = nil
end

function TestCursor:test_query_fails()
    self.assertions:assert_execute_fails("select",
                                         "E%-EDL%-6: Error executing statement 'select': E%-EDL%-10: " ..
                                             "Received DB status 'error' with code 42000: 'syntax error, " ..
                                             "unexpected ';' %[line 1, column 7%] %(Session: %d+%)'")
end

function TestCursor:test_select_single_column_single_row()
    self.assertions:assert_rows("select 1", {{1}})
end

function TestCursor:test_select_multiple_columns_single_row()
    self.assertions:assert_rows("select 'a', 'b', 'c'", {{"a", "b", "c"}})
end

function TestCursor:test_select_multiple_columns_multiple_rows()
    self.assertions:assert_rows(
        "select t.* from (values (1, 'a'), (2, 'b'), (3, 'c')) as t(num, txt)",
        {{1, "a"}, {2, "b"}, {3, "c"}})
end

function TestCursor:test_using_closed_cursor_fails()
    local cursor = assert(self.connection:execute("select 1"))
    cursor:close()
    luaunit.assertErrorMsgMatches(
        ".*E%-EDL%-13: Cursor closed while trying to fetch datasets from cursor",
        function() cursor:fetch() end)
end

function TestCursor:test_closing_closed_cursor_succeeds()
    local cursor = assert(self.connection:execute("select 1"))
    cursor:close()
    cursor:close()
end

os.exit(luaunit.LuaUnit.run())
