local luaunit = require("luaunit")
local config = require("config")

TestCursor = {}

function TestCursor:setUp()
    self.conn = config.create_connection()
    luaunit.assertNotNil(self.conn)
end

function TestCursor:execute(statement)
    local cursor, err =self.conn:execute(statement)
    if err then
        luaunit.fail("Expected statement '"..statement.."' to succeed but got error "..tostring(err))
    end
    luaunit.assertNotNil(cursor)
    return cursor
end

function TestCursor:test_connection_succeeds()
    local cursor = self:execute("select 1")
    luaunit.assertNotNil(cursor)
    luaunit.assertEquals(cursor:fetch(), {1})
    luaunit.assertNil(cursor:fetch())
end

function TestCursor:tearDown()
    self.conn:close()
end

os.exit(luaunit.LuaUnit.run())
