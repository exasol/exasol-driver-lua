local driver = require("luasql.exasol")
local log = require("remotelog")

local M = {}

local function get_optional_system_env(varname, default)
    local value = os.getenv(varname)
    if value == nil then
        return default
    end
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
    debug_mode = 1
end

function M.create_environment()
    M.configure_logging()
    return driver.exasol()
end

function M.configure_logging()
    local luws_trace = get_optional_system_env("LUWS_TRACE", nil)
    if luws_trace == "TRACE" then
        enable_luws_trace_log()
    end
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

function M.db_supports_openssl_module()
    return M._is_exasol_8()
end

local function starts_with(text, prefix)
    return text:find(prefix, 1, true) == 1
end

function M._is_exasol_8()
    return starts_with(M._get_exasol_version(), "8.")
end

function M._get_exasol_version()
    if not M._exasol_version then
        M._exasol_version = M._read_exasol_version()
    end
    return M._exasol_version
end

local function try_finally(try, finally)
    local ok, result = pcall(try)
    finally()
    if not ok then
        log.warn("Error in try: %s", result)
        error(result)
    else
        return result
    end
end

local function try_with_closable(closable_creator, try)
    local closeable = closable_creator()
    return try_finally(function()
        return try(closeable)
    end, function()
        closeable:close()
    end)
end

function M._execute_query(query, fetchmode)
    return try_with_closable(M.create_connection, function(conn)
        return try_with_closable(function()
            return assert(conn:execute(query))
        end, function(cur)
            local rows = {}
            local row = assert(cur:fetch({}, fetchmode))
            while row ~= nil do
                table.insert(rows, row)
                row = cur:fetch({}, fetchmode)
            end
            return rows
        end)
    end)
end

function M._read_exasol_version()
    local rows = M._execute_query("select param_value from exa_metadata where param_name = 'databaseProductVersion'",
                                  "n")
    local version = rows[1][1]
    log.info("Found Exasol version '%s'", version)
    assert(version, "Error getting version")
    return version
end

return M
