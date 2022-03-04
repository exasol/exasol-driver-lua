local luaunit = require("luaunit")
local config = require("config")
local assertions = require("assertions")

TestCursor = {}

function TestCursor:setUp()
    self.conn = config.create_connection()
    luaunit.assertNotNil(self.conn)
    self.assertions = assertions:new(self.conn)
end


function TestCursor:test_query_fails()
    self.assertions:assert_execute_fails("select",
                              "E-EDL-6: Error executing statement 'select': E-EDL-10: " ..
                                  "Received status 'error' with code 42000: missing value")
end

function TestCursor:test_select_single_column_single_row()
    self.assertions:assert_rows( "select 1", {{1}})
end

function TestCursor:test_select_multiple_columns_single_row()
    self.assertions:assert_rows( "select 'a', 'b', 'c'",
                          {{"a", "b", "c"}})
end

function TestCursor:test_select_multiple_columns_multiple_rows()
    self.assertions:assert_rows(
                          "select * from sys.exa_sql_keywords where keyword like 'AB%' order by keyword",
                          {{"ABS", false}, {"ABSOLUTE", true}})
end

function TestCursor:test_using_closed_cursor_fails()
    local cursor = self.assertions:execute("select 1")
    cursor:close()
    luaunit.assertErrorMsgMatches(".*E%-EDL%-13: Cursor already closed",
                                  function() cursor:fetch() end)
end

function TestCursor:test_closing_closed_cursor_succeeds()
    local cursor = self.assertions:execute("select 1")
    cursor:close()
    cursor:close()
end

function TestCursor:tearDown() self.conn:close() end

os.exit(luaunit.LuaUnit.run())
