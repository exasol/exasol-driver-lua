local log = require("remotelog")

local M = {}

local function get_optional_system_env(varname, default)
    local value = os.getenv(varname)
    if value == nil then
        return default
    end
    return value
end

function M.get_connection_params(override)
    override = override or {}
    local host = override.host or get_optional_system_env("EXASOL_HOST", "localhost")
    local port = override.port or get_optional_system_env("EXASOL_PORT", "8563")
    return {
        host = host,
        port = port,
        source_name = string.format("%s:%s", host, port),
        user = override.user or get_optional_system_env("EXASOL_USER", "sys"),
        password = override.password or get_optional_system_env("EXASOL_PASSWORD", "exasol"),
        fingerprint = override.fingerprint or nil
    }
end

local function enable_luws_trace_log()
    log.debug("Enable luws tracing")
    -- luacheck: globals debug_mode
    debug_mode = 1
end

function M.configure_logging()
    local luws_trace = get_optional_system_env("LUWS_TRACE", nil)
    if luws_trace == "TRACE" then
        enable_luws_trace_log()
    end
    local log_level = string.upper(get_optional_system_env("LOG_LEVEL", "INFO"))
    log.set_level(log_level)
end

return M
