require("busted.runner")()
local driver = require("luasql.exasol")
local config = require("config")
local log = require("remotelog")
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
            assert(conn:execute(string.format("drop schema if exists %s cascade", schema_name)))
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

    local function read_file(file)
        local f = assert(io.open(file, "rb"))
        local content = f:read("*all")
        f:close()
        return content
    end

    local function execute_query_in_udf(query)
        local script = read_file("./spec/integration/udf_script.lua")
        local script_arguments =
                "source_name VARCHAR(100), user_name VARCHAR(100), password VARCHAR(100), query VARCHAR(2000)"
        local schema_name = create_schema()
        create_script_with_driver(schema_name, script_arguments, script)
        local escaped_query = escape_string(query)
        local cursor = assert(conn:execute(string.format("select %s.RUN_TEST('%s', '%s', '%s', '%s')", schema_name,
                                                         connection_params.source_name, connection_params.user,
                                                         connection_params.password, escaped_query)))
        local result = cursor:fetch()[1]
        cursor:close()
        return result
    end

    it("can execute query in UDF", function()
        if not config.db_supports_openssl_module() then
            log.warn("Skipping test because current Exasol version does not support openssl module")
            return
        end
        local result = execute_query_in_udf("select t.* from (values (1, 'a'), (2, 'b'), (3, 'c')) as t(num, txt)")
        assert.is_same([[Column names: [NUM, TXT]
Column types: [DECIMAL, VARCHAR]
Row 1: [1, a]
Row 2: [2, b]
Row 3: [3, c]
]], result)
    end)
end)

