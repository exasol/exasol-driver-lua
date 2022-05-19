---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasql.exasol")
local config = require("config")

config.configure_logging()
local connection_params = config.get_connection_params()
local amalgamated_file_path = nil

local function get_amalgamated_file()
    if amalgamated_file_path then return amalgamated_file_path end
    local success, result, status = os.execute("tools/amalg.sh")
    assert.is_true(success)
    assert.is_same("exit", result)
    assert.is_same(0, status)
    amalgamated_file_path = "target/exasol-driver-amalg.lua"
    local file = assert(io.open(amalgamated_file_path, "r"))
    assert.is_not_nil(file, "Amalgamated file " .. amalgamated_file_path .. " not found")
    file:close()
    return amalgamated_file_path
end

local function read_amalgamated_file()
    local path = get_amalgamated_file()
    local file = assert(io.open(path, "r"))
    local content = file:read("*all")
    file:close()
    return content
end

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

    it("creating udf works", function()
        local schema_name = create_schema()
        local content = read_amalgamated_file()
        local statement = "CREATE OR REPLACE LUA SCALAR SCRIPT " .. schema_name .. ".EXASOL_DRIVER() RETURNS INT AS " ..
                                  content
        assert(conn:execute(statement))
        assert(conn:execute("CREATE OR REPLACE LUA SCALAR SCRIPT " .. schema_name ..
                                    ".RUN_TEST() RETURNS VARCHAR(2000) AS\n" .. --
        'exa.import("' .. schema_name .. '.EXASOL_DRIVER", "EXASOL")\n' .. [[
function run(ctx)
    --return tostring(exasol.exasol())
    return "blubb"
end
]]))
        local cursor = assert(conn:execute("select " .. schema_name .. ".RUN_TEST()"))
        local result = cursor:fetch()
        cursor:close()
        print("result: " .. result[1])
    end)
end)

