---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasqlexasol")
local config = require("config")

config.configure_logging()

describe("Cursor with resultset handle", function()
    local env = nil

    local function create_schema(connection)
        local schema_name = string.format("CONNECTION_TEST_%d", os.time())
        assert(connection:execute(string.format("drop schema if exists %s cascade", schema_name)))
        assert(connection:execute(string.format("create schema %s", schema_name)))
        return schema_name
    end

    local function drop_schema(connection, schema_name)
        assert(connection:execute(string.format("drop schema %s cascade", schema_name)))
    end

    before_each(function() env = driver.exasol() end)

    after_each(function()
        env:close()
        env = nil
    end)

    local function insert_data(connection, qualified_table_name, num_rows)
        assert(connection:execute(string.format("create table %s (id integer)", qualified_table_name)))
        local insert_statement = string.format("insert into %s (id) values between 1 and %d", qualified_table_name,
                                               num_rows)
        assert(connection:execute(insert_statement))
    end

    local function create_connection(properties)
        properties = properties or {}
        local connection_params = config.get_connection_params()
        return assert(env:connect(connection_params.source_name, connection_params.user, connection_params.password,
                                  properties))
    end

    local function assert_cursor_returns_expected_rows(cursor, expected_row_count)
        local data = {}
        for expected_row = 1, expected_row_count do --
            assert.is_same({expected_row}, cursor:fetch(data))
        end
        assert.is_false(cursor.closed)
        assert.is_nil(cursor:fetch(data))
        assert.is_true(cursor.closed)
        cursor:close()
    end

    local function test_result_with(row_count)
        local connection = create_connection()
        local schema_name = create_schema(connection)
        local table_name = string.format('"%s"."t"', schema_name)
        insert_data(connection, table_name, row_count)
        local cursor = assert(connection:execute(string.format("select * from %s", table_name)))
        assert_cursor_returns_expected_rows(cursor, row_count)
        drop_schema(connection, schema_name)
        connection:close()
    end

    it("fetches small result sets with default fetchsize", function() test_result_with(999) end)

    it("fetches large result sets with default fetchsize [itest -> dsn~luasql-cursor-fetch-resultsethandle~0]",
       function() test_result_with(2000) end)

    it("fetches large result sets with small fetchsize [itest -> dsn~luasql-cursor-fetch-resultsethandle~0]", function()
        create_connection({fetchsize_kib = 5})
        test_result_with(2000)
    end)
    it("fetches large result sets with large fetchsize [itest -> dsn~luasql-cursor-fetch-resultsethandle~0]", function()
        create_connection({fetchsize_kib = 50000})
        test_result_with(2000)
    end)
end)
