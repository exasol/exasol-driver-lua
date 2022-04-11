---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local cjson = require("cjson")
local driver = require("luasqlexasol")
local config = require("config")

config.configure_logging()

describe("Cursor with resultset handle", function()
    local env = nil
    local connection = nil
    local schema_name = nil

    local function insert_data(num_rows)
        assert(connection:execute(string.format("insert into %s.t (id) values between 1 and %d", schema_name, num_rows)))
    end

    local function create_test_data()
        assert(connection:execute(string.format("drop schema if exists %s cascade", schema_name)))
        assert(connection:execute(string.format("create schema %s", schema_name)))
        assert(connection:execute(string.format("create table t (id integer)")))
    end

    before_each(function()
        schema_name = string.format("connection_test_%d", os.time())
        env = driver.exasol()
        local connection_params = config.get_connection_params()
        connection = assert(env:connect(connection_params.source_name, connection_params.user,
                                        connection_params.password))
        create_test_data()
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

    it("supports fetching small result sets", function()
        insert_data(1000)
        local cursor = assert(connection:execute("select * from t"))
        local data = {}
        for expected_row = 1, 1000 do assert.is_same({expected_row}, cursor:fetch(data)) end
        assert.is_nil(cursor:fetch(data))
        cursor:close()
    end)

    it("supports fetching large result sets", function()
        insert_data(2000)
        local cursor = assert(connection:execute("select * from t"))
        local data = {}
        for expected_row = 1, 2000 do assert.is_same({expected_row}, cursor:fetch(data)) end
        assert.is_nil(cursor:fetch(data))
        cursor:close()
    end)

end)
