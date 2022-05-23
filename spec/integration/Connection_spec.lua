---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasql.exasol")
local config = require("config")
config.configure_logging()

describe("Connection", function()
    local env = nil
    local connection = nil

    local function create_connection()
        local connection_params = config.get_connection_params()
        return assert(env:connect(connection_params.source_name, connection_params.user, connection_params.password))
    end

    local function create_schema()
        local schema_name = string.format("CONNECTION_TEST_%d", os.time())
        assert(connection:execute(string.format("drop schema if exists %s cascade", schema_name)))
        assert(connection:execute(string.format("create schema %s", schema_name)))
        finally(function() assert(connection:execute(string.format("drop schema %s cascade", schema_name))) end)
        return schema_name
    end

    local function create_table(schema_name, table_name)
        local qualified_table_name = string.format('"%s"."%s"', schema_name, table_name)
        assert(connection:execute(string.format("create table %s (id integer constraint primary key, name varchar(10))",
                                                qualified_table_name)))
        return qualified_table_name
    end

    local function insert_row(table_name, id, name)
        local row_count = assert(connection:execute(string.format("insert into %s values (%d, '%s')", table_name, id,
                                                                  name)))
        assert.is_same(1, row_count, "row inserted")
    end

    local function assert_row_count_in_new_connection(table_name, expected_row_count)
        local other_connection = create_connection()
        finally(function() other_connection:close() end)
        local cursor = assert(other_connection:execute(string.format("select count(*) from %s", table_name)))
        finally(function() cursor:close() end)
        local actual_row_count = cursor:fetch()[1]
        assert.same(expected_row_count, actual_row_count, "row count")
    end

    local function set_autocommit(autocommit)
        assert.is_true(connection:setautocommit(autocommit), "setautocommit result")
    end

    before_each(function()
        env = driver.exasol()
        connection = create_connection()
    end)

    after_each(function()
        if connection and not connection.closed then
            assert.is_true(connection:close(), "Not all cursors were closed in test cleanup")
        end
        env:close()
        env = nil
        connection = nil
    end)

    describe("execute()", function()

        -- [itest -> dsn~luasql-connection-execute~0]
        it("executes a select query", function()
            local cursor = assert(connection:execute("select 1"))
            assert.is_same({1}, cursor:fetch())
            assert.is_nil(cursor:fetch())
            cursor:close()
        end)

        it("allows creating a table", function()
            create_schema()
            local result = assert(connection:execute("create table test_table (id integer, name varchar(10))"))
            assert.is_same(0, result)

            local cursor = assert(connection:execute("select count(*) from test_table"))
            assert.is_same({0}, cursor:fetch())
            assert.is_nil(cursor:fetch())
        end)

        it("allows inserting into a table", function()
            create_schema()
            assert(connection:execute("create table test_table (id integer, name varchar(10))"))

            local result = assert(connection:execute("insert into test_table values (1, 'a')"))
            assert.is_same(1, result)

            result = assert(connection:execute("insert into test_table values (2, 'b'), (3, 'c')"))
            assert.is_same(2, result)

            local cursor = assert(connection:execute("select count(*) from test_table"))
            assert.is_same({3}, cursor:fetch())
            assert.is_nil(cursor:fetch())
        end)

        it("allows selecting from a table", function()
            create_schema()
            assert(connection:execute("create table test_table (id integer, name varchar(10))"))
            assert(connection:execute("insert into test_table values (1, 'a'), (2, 'b'), (3, 'c')"))

            local cursor = assert(connection:execute("select * from test_table order by id"))
            assert.is_same({1, "a"}, cursor:fetch())
            assert.is_same({2, "b"}, cursor:fetch())
            assert.is_same({3, "c"}, cursor:fetch())
            assert.is_nil(cursor:fetch())
        end)

        it("allows using update query", function()
            create_schema()
            assert(connection:execute("create table test_table (id integer, name varchar(10))"))
            assert(connection:execute("insert into test_table values (1, 'a'), (2, 'b'), (3, 'c')"))

            local result = assert(connection:execute("update test_table set name = name || name where id >= 2"))
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
    end)

    describe("commit()", function()
        it("returns true for empty transaction", function()
            set_autocommit(false)
            assert.is_true(connection:commit())
        end)

        it("returns true when autocommit is on", function()
            set_autocommit(true)
            assert.is_true(connection:commit())
        end)

        it("returns true for non-empty transaction", function()
            local schema_name = create_schema()
            local table_name = create_table(schema_name, "tab")
            set_autocommit(false)
            insert_row(table_name, 1, "a")
            assert.is_true(connection:commit())
        end)

        it("commits a transaction", function()
            local schema_name = create_schema()
            local table_name = create_table(schema_name, "tab")
            set_autocommit(false)
            insert_row(table_name, 1, "a")
            assert_row_count_in_new_connection(table_name, 0)
            connection:commit()
            assert_row_count_in_new_connection(table_name, 1)
        end)
    end)

    describe("setautocommit()", function()
        it("enables autocommit by default", function()
            local schema_name = create_schema()
            local table_name = create_table(schema_name, "tab")
            insert_row(table_name, 1, "a")
            assert_row_count_in_new_connection(table_name, 1)
        end)

        it("enables autocommit", function()
            local schema_name = create_schema()
            local table_name = create_table(schema_name, "tab")
            set_autocommit(true)
            insert_row(table_name, 1, "a")
            assert_row_count_in_new_connection(table_name, 1)
        end)

        it("disables autocommit", function()
            local schema_name = create_schema()
            local table_name = create_table(schema_name, "tab")
            set_autocommit(false)
            insert_row(table_name, 1, "a")
            assert_row_count_in_new_connection(table_name, 0)
        end)

        it("requires explicit commit when disabled", function()
            local schema_name = create_schema()
            local table_name = create_table(schema_name, "tab")
            set_autocommit(false)
            insert_row(table_name, 1, "a")
            assert(connection:execute("commit"))
            assert_row_count_in_new_connection(table_name, 1)
        end)
    end)

    describe("close()", function()
        it("doesn't fail when closing a closed connection", function()
            connection:close()
            connection:close()
        end)

        -- [itest -> dsn~luasql-connection-close~0]
        it("does not close cursors", function()
            local cursor = assert(connection:execute("select 1"))
            connection:close()
            assert.same({1}, cursor:fetch())
            cursor:close()
        end)
    end)
end)

