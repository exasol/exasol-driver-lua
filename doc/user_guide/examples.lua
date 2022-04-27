local log = require("remotelog")
local driver = require("luasqlexasol")
local environment = driver.exasol()

local function get_config()
    local function get_system_env(varname, default)
        local value = os.getenv(varname) or default
        if value == nil then error("Environment variable '" .. varname .. "' is required but is not defined") end
        return value
    end

    return {
        host = get_system_env("EXASOL_HOST"),
        port = get_system_env("EXASOL_PORT", 8563),
        user = get_system_env("EXASOL_USER", "sys"),
        password = get_system_env("EXASOL_PASSWORD", "exasol")
    }
end

-- Set log level to INFO
log.set_level("INFO")

local config = get_config()
local source_name = config.host .. ":" .. config.port
local properties = {tls_verify = "none", tls_protocol = "tlsv1_2", tls_options = "no_tlsv1"}
local connection = environment:connect(source_name, config.user, config.password, properties)
log.info("Successfully connected to Exasol database at %s with user %s", source_name, config.user)

local cursor = connection:execute("SELECT ROUND(RANDOM(1, 6)) AS DICE_ROLL")

local column_list = cursor:fetch()
log.info("Dice roll result: %d", column_list[1])

if cursor:fetch() == nil then
    log.debug("No more rows available")
else
    error("Expected only a single line")
end

if cursor.closed then
    log.debug("Cursor already closed at last fetch()")
else
    if cursor:close() then
        log.debug("Cursor closed successfully")
    else
        error("Failed to close cursor")
    end
end

if connection:close() then
    log.debug("Connection closed successfully")
else
    error("Failed to close connection")
end

if environment:close() then
    log.debug("Environment closed successfully")
else
    error("Failed to close environment")
end
