---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasqlexasol")
local config = require("config")

config.configure_logging()

describe("Connection", function()
    local env = nil
    local connection = nil
    local schema_name = nil

    before_each(function()
        env = driver.exasol()
        schema_name = string.format("connection_test_%d", os.time())
        local connection_params = config.get_connection_params()
        connection = assert(env:connect(connection_params.source_name, connection_params.user,
                                        connection_params.password))
        assert(connection:execute(string.format("drop schema if exists %s cascade", schema_name)))
        assert(connection:execute(string.format("create schema %s", schema_name)))
    end)

    after_each(function()
        connection:close()
        env:close()
        env = nil
        connection = nil
    end)

    -- [itest -> dsn~luasql-connection-execute~0]
    it("executes a select query", function()
        local cursor = assert(connection:execute("select 1"))
        assert.is_same({1}, cursor:fetch())
        assert.is_nil(cursor:fetch())
    end)

    it("allows creating and using tables", function()
        local result = assert(connection:execute("create table test_table (id integer, name varchar(10))"))
        assert.is_same(0, result)

        result = assert(connection:execute("insert into test_table values (1, 'a')"))
        assert.is_same(1, result)

        result = assert(connection:execute("insert into test_table values (2, 'b'), (3, 'c')"))
        assert.is_same(2, result)

        local cursor = assert(connection:execute("select * from test_table order by id"))
        assert.is_same({1, "a"}, cursor:fetch())
        assert.is_same({2, "b"}, cursor:fetch())
        assert.is_same({3, "c"}, cursor:fetch())
        assert.is_nil(cursor:fetch())
    end)

    it("allows using update query", function()
        local result = assert(connection:execute("create table test_table (id integer, name varchar(10))"))
        assert.is_same(0, result)

        result = assert(connection:execute("insert into test_table values (1, 'a'), (2, 'b'), (3, 'c')"))
        assert.is_same(3, result)

        result = assert(connection:execute("update test_table set name = name || name where id >= 2"))
        assert.is_same(2, result)

        local cursor = assert(connection:execute("select * from test_table order by id"))
        assert.is_same({1, "a"}, cursor:fetch())
        assert.is_same({2, "bb"}, cursor:fetch())
        assert.is_same({3, "cc"}, cursor:fetch())
        assert.is_nil(cursor:fetch())
    end)

    it("returns error when executing an invalid query", function()
        local cursor, err = connection:execute("select")
        assert.is_nil(cursor)
        assert.matches("E%-EDL%-6: Error executing statement 'select': E%-EDL%-10: Received DB status 'error' " ..
                               "with code 42000: 'syntax error, unexpected ';'", tostring(err))
    end)

    it("fails executing a query when already closed", function()
        connection:close()
        assert.has_error(function() connection:execute("select 1") end,
                         "E-EDL-12: Connection already closed when trying to call 'execute'")
    end)

    it("doesn't fail when closing a closed connection", function()
        connection:close()
        connection:close()
    end)

    -- [itest -> dsn~luasql-connection-close~0]
    it("closes cursors", function()
        local cursor = assert(connection:execute("select 1"))
        connection:close()
        assert.has_error(function() cursor:fetch() end,
                         "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
    end)
end)

