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
        error("Environment variable '" .. varname .. "' is not defined")
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
    return driver.exasol({log_level = M.get_system_env("LOG_LEVEL", "INFO")})
end

return M