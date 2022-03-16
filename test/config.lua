local luaunit = require("luaunit")
local driver = require("luasqlexasol")
local log = require("remotelog")

local M = {}

local function get_optional_system_env(varname, default)
    local value = os.getenv(varname)
    if value == nil then return default end
    return value
end

local function get_system_env(varname, default)
    local value = get_optional_system_env(varname, default)
    if value == nil and default == nil then
        error("Environment variable '" .. varname ..
                  "' required for test is not defined")
    end
    return value
end

function M.get_connection_params(override)
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

local function enable_luws_trace_log()
    -- luacheck: globals debug_mode
    debug_mode = 1
end

function M.create_environment()
    local log_level = string.upper(get_system_env("LOG_LEVEL", "INFO"))
    if log_level == "TRACE" then
        enable_luws_trace_log()
    end
    log.set_level(log_level)
    return driver.exasol()
end

function M.create_connection()
    local params = M.get_connection_params()
    local env = M.create_environment()
    local source_name = params.host .. ":" .. params.port
    local conn, err = env:connect(source_name, params.user, params.password)
    luaunit.assertNil(err, "no error when connecting to " .. source_name)
    luaunit.assertNotNil(conn, "connection available")
    return conn
end

return M
