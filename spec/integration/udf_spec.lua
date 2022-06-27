---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasql.exasol")
local config = require("config")
local amalg = require("amalg_util")

config.configure_logging()
local connection_params = config.get_connection_params()

-- [itest -> dsn~use-available-exasol-udf-libraries-only~1]
describe("Exasol driver works inside an UDF", function()
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
        finally(function()
            assert(conn:execute(string.format("drop schema %s cascade", schema_name)))
        end)
        return schema_name
    end

    local function create_script_with_driver(schema_name, script_arguments, script_content)
        local content = amalg.amalgamate_with_script(script_content)
        local statement = string.format("CREATE LUA SCALAR SCRIPT %s.RUN_TEST(%s) RETURNS VARCHAR(2000) AS\n%s\n/",
                                        schema_name, script_arguments, content)
        assert(conn:execute(statement))
    end

    local function escape_string(string)
        return string:gsub("'", "''")
    end

    it("creating udf works", function()
        local script = [[
local driver = require("luasql.exasol")
function run(ctx)
    local env = driver.exasol()
    local conn = assert(env:connect(ctx.source_name, ctx.user_name, ctx.password))
    local cur = assert(conn:execute(ctx.query))
    local index = 1
    local result = ""
    local row = {}
    row = assert(cur:fetch(row, "n"))
    while row ~= nil do
        result = string.format("%sRow %d: [%s]\n", result, index, table.concat(row, ", "))
        row = cur:fetch(row, "n")
        index = index + 1
    end
    cur:close()
    conn:close()
    env:close()
    return result
end
]]
        local script_arguments =
                "source_name VARCHAR(100), user_name VARCHAR(100), password VARCHAR(100), query VARCHAR(2000)"
        local schema_name = create_schema()
        create_script_with_driver(schema_name, script_arguments, script)
        local query = escape_string("select t.* from (values (1, 'a'), (2, 'b'), (3, 'c')) as t(num, txt)")
        local cursor = assert(conn:execute(string.format("select %s.RUN_TEST('%s', '%s', '%s', '%s')", schema_name,
                                                         connection_params.source_name, connection_params.user,
                                                         connection_params.password, query)))
        local result = cursor:fetch()[1]
        cursor:close()
        assert.is_same([[Row 1: [1, a]
Row 2: [2, b]
Row 3: [3, c]
]], result)
    end)
end)

