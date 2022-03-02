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
        fingerprint = override.fingerprint or
            get_system_env("EXASOL_CERT_FINGERPRINT")
    }
end

function test_connection_fails()
    local real_connection = get_connection_params()
    local tests = {
        {
            props = get_connection_params({host = "wronghost"}),
            expected_error = "E-EDL-1: Error connecting to 'wss://wronghost:8563': 'Connection to wronghost:8563 failed: host or service not provided, or not known'"
        }, {
            props = get_connection_params({port = "1234"}),
            expected_error = string.format(
                "E-EDL-1: Error connecting to 'wss://%s:1234': 'Connection to %s:1234 failed: connection refused'",
                real_connection.host, real_connection.host)
        }, {
            props = get_connection_params({user = "unknownUser"}),
            expected_error = "E-EDL-2: Did not receive response for payload"
        }, {
            props = get_connection_params({password = "wrong password"}),
            expected_error = "E-EDL-2: Did not receive response for payload"
        }
    }
    for _, test in ipairs(tests) do
        local env = create_environment()
        local sourcename = test.props.host .. ":" .. test.props.port
        luaunit.assertErrorMsgContentEquals(test.expected_error, function()
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
    connection:close()
    env:close()
end

os.exit(luaunit.LuaUnit.run())
