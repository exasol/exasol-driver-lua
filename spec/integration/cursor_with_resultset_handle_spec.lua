---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasqlexasol")
local config = require("config")
local log = require("remotelog")

config.configure_logging()

describe("Cursor with resultset handle", function()
    local env = nil
    local connection = nil
    local schema_name = nil

    local function create_schema()
        assert(connection:execute(string.format("drop schema if exists %s cascade", schema_name)))
        assert(connection:execute(string.format("create schema %s", schema_name)))
        assert(connection:execute(string.format("create table t (id integer)")))
    end

    before_each(function()
        schema_name = string.format("connection_test_%d", os.time())
        env = driver.exasol()
    end)

    after_each(function()
        if connection and not connection.closed then
            assert(connection:execute(string.format("drop schema %s cascade", schema_name)))
            connection:close()
        end
        env:close()
        env = nil
        connection = nil
    end)

    local function insert_data(num_rows)
        local insert_statement = string.format("insert into %s.t (id) values between 1 and %d", schema_name, num_rows)
        assert(connection:execute(insert_statement))
    end

    local function create_connection(properties)
        properties = properties or {}
        local connection_params = config.get_connection_params()
        connection = assert(env:connect(connection_params.source_name, connection_params.user,
                                        connection_params.password, properties))
    end

    local function test_result_with(row_count)
        if not connection then create_connection() end
        create_schema()
        insert_data(row_count)
        local cursor = assert(connection:execute("select * from t"))
        local data = {}
        for expected_row = 1, row_count do assert.is_same({expected_row}, cursor:fetch(data)) end
        assert.is_nil(cursor:fetch(data))
        cursor:close()
    end

    it("fetches small result sets with default fetchsize", function() test_result_with(999) end)

    it("fetches large result sets with default fetchsize [itest -> dsn~luasql-cursor-fetch-resultsethandle~0]",
       function() test_result_with(2000) end)

    it("fetches large result sets with small fetchsize [itest -> dsn~luasql-cursor-fetch-resultsethandle~0]", function()
        create_connection({fetchsize_kb = 5})
        test_result_with(2000)
    end)
end)
