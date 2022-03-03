local luaunit = require("luaunit")
local driver = require("luasqlexasol")

function test_version() luaunit.assertEquals(driver.VERSION, "0.1.0") end

local function get_optional_system_env(varname, default)
    local value = os.getenv(varname)
    if value == nil then return default end
    return value
end

local function get_system_env(varname, default)
    local value = get_optional_system_env(varname, default)
    if value == nil and default == nil then
        error("Environment variable '" .. varname .. "' is not defined")
    end
    return value
end

local function create_environment()
    return driver.exasol({log_level = get_system_env("LOG_LEVEL", "INFO")})
end

local function get_connection_params(override)
    override = override or {}
    return {
        host = override.host or get_system_env("EXASOL_HOST"),
        port = override.port or get_system_env("EXASOL_PORT", "8563"),
        user = override.user or get_system_env("EXASOL_USER", "sys"),
        password = override.password or
            get_system_env("EXASOL_PASSWORD", "exasol"),
        fingerprint = override.fingerprint or nil
    }
end

function test_connection_fails()
    local real_connection = get_connection_params()
    local tests = {
        {
            props = get_connection_params({host = "wronghost"}),
            expected_error_pattern = ".*E%-EDL%-1: Error connecting to 'wss://wronghost:8563': .*"
        }, {
            props = get_connection_params({port = "1234"}),
            expected_error_pattern = ".*E%-EDL%-1: Error connecting to 'wss://" ..
                real_connection.host .. ":1234': .*"
        }, {
            props = get_connection_params({user = "unknownUser"}),
            expected_error_pattern = ".*E%-EDL%-2: Did not receive response for payload. " ..
                "Username or password may be wrong..*"
        }, {
            props = get_connection_params({password = "wrong password"}),
            expected_error_pattern = ".*E%-EDL%-2: Did not receive response for payload. " ..
                "Username or password may be wrong..*"
        }
    }
    for _, test in ipairs(tests) do
        local env = create_environment()
        local sourcename = test.props.host .. ":" .. test.props.port
        luaunit.assertErrorMsgMatches(test.expected_error_pattern, function()
            env:connect(sourcename, test.props.user, test.props.password)
        end)
        env:close()
    end
end

function test_connection_succeeds()
    local params = get_connection_params()
    local env = create_environment()
    local sourcename = params.host .. ":" .. params.port
    local connection = env:connect(sourcename, params.user, params.password)
    luaunit.assertNotNil(connection)
    print("cursoer", connection, connection.cursors)
    local cursor = connection:execute("select 1")
    luaunit.assertNotNil(cursor)
    luaunit.assertNotNil(cursor.fetch())
    cursor:close()
    connection:close()
    env:close()
end

os.exit(luaunit.LuaUnit.run())
