local driver = require("luasql.exasol")
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
        error("Environment variable '" .. varname .. "' required for test is not defined")
    end
    return value
end

function M.get_connection_params(override)
    override = override or {}
    local host = override.host or get_system_env("EXASOL_HOST")
    local port = override.port or get_system_env("EXASOL_PORT", "8563")
    return {
        host = host,
        port = port,
        source_name = string.format("%s:%s", host, port),
        user = override.user or get_system_env("EXASOL_USER", "sys"),
        password = override.password or get_system_env("EXASOL_PASSWORD", "exasol"),
        fingerprint = override.fingerprint or nil
    }
end

local function enable_luws_trace_log()
    log.debug("Enable luws tracing")
    -- luacheck: globals debug_mode
    ---@diagnostic disable-next-line: lowercase-global
    debug_mode = 1
end

function M.create_environment()
    M.configure_logging()
    return driver.exasol()
end

function M.configure_logging()
    local luws_trace = get_optional_system_env("LUWS_TRACE", nil)
    if luws_trace == "TRACE" then enable_luws_trace_log() end
    local log_level = string.upper(get_system_env("LOG_LEVEL", "INFO"))
    log.set_level(log_level)
end

function M.create_connection()
    local params = M.get_connection_params()
    local env = M.create_environment()
    local source_name = params.host .. ":" .. params.port
    local conn = assert(env:connect(source_name, params.user, params.password))
    return conn
end

return M
