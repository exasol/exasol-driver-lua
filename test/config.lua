local luaunit = require("luaunit")
local driver = require("luasqlexasol")

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

function M.create_environment()
    local options = {log_level = get_system_env("LOG_LEVEL", "INFO")}
    return driver.exasol(options)
end

function M.create_connection()
    local params = M.get_connection_params()
    local env = M.create_environment()
    local sourcename = params.host .. ":" .. params.port
    local conn = env:connect(sourcename, params.user, params.password)
    luaunit.assertNotNil(conn)
    return conn
end

return M
