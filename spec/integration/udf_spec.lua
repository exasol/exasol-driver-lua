---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasql.exasol")
local config = require("config")
local amalg = require("amalg_util")

config.configure_logging()
local connection_params = config.get_connection_params()

describe("driver works inside an UDF", function()
    local env = nil
    local conn = nil

    before_each(function()
        env = driver.exasol()
        conn = env:connect(connection_params.source_name, connection_params.user, connection_params.password)
    end)

    after_each(function()
        assert.is_true(conn:close())
        conn = nil
        assert.is_true(env:close())
        env = nil
    end)

    local function create_schema()
        local schema_name = string.format("CONNECTION_TEST_%d", os.time())
        assert(conn:execute(string.format("drop schema if exists %s cascade", schema_name)))
        assert(conn:execute(string.format("create schema %s", schema_name)))
        finally(function() assert(conn:execute(string.format("drop schema %s cascade", schema_name))) end)
        return schema_name
    end

    local function create_script_with_driver(schema_name, script_content)
        local content = amalg.amalgamate_with_script(script_content)
        local statement = "CREATE OR REPLACE LUA SCALAR SCRIPT " .. schema_name ..
                                  ".RUN_TEST(lua_script VARCHAR(2000)) RETURNS VARCHAR(2000) AS\n" .. content .. "\n/"
        assert(conn:execute(statement))
    end

    it("creating udf works", function()
        local script = [[
local driver = require("luasql.exasol")
function run(ctx)
    return "Loaded driver: "..tostring(driver)
end
]]
        local schema_name = create_schema()
        create_script_with_driver(schema_name, script)

        local cursor = assert(conn:execute("select " .. schema_name .. ".RUN_TEST('blah')"))
        local result = cursor:fetch()
        cursor:close()
        print("result: " .. result[1])
    end)
end)

