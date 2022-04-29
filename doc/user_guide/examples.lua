--- Example usage of the LuaSQL driver for Exasol
-- @script examples.lua
local log = require("remotelog")

-- This function reads the connection configuration
-- from system environment variables
local function get_config()
    local function get_system_env(varname, default)
        local value = os.getenv(varname) or default
        if value == nil then
            error("Environment variable '" .. varname ..
                          "' is required but is not defined")
        end
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

-- Get connection configuration
local config = get_config()
local source_name = config.host .. ":" .. config.port

-- Import the library
local driver = require("luasqlexasol")

-- Create a new environment
local environment = driver.exasol()

--
-- Create a new connection
--

-- Define optional connection properties
local properties = {
    tls_verify = "none",
    tls_protocol = "tlsv1_2",
    tls_options = "no_tlsv1"
}

-- Create the connection
local connection, err = environment:connect(source_name, config.user,
                                            config.password, properties)
-- Handle connection error
if err == nil then
    log.info(
            "Successfully connected to Exasol database at %s with user %s",
            source_name, config.user)
else
    error("Connection failed: " .. err)
end

--
-- Execute a query and read a single row
--
local cursor
cursor, err = connection:execute("SELECT ROUND(RANDOM(1, 6)) AS DICE_ROLL")
-- Handle query error
if err == nil then
    log.info("Successfully executed query")
else
    error("Query failed: " .. err)
end

-- Fetch query result
local first_row = cursor:fetch()
log.info("Dice roll result: %d", first_row[1])

-- Close cursor and check if it was closed successfully
if cursor:close() then
    log.info("Cursor closed successfully")
else
    error("Failed to close cursor")
end

--
-- Execute a query and iterate over the result using alphanumeric indices
--
log.info("Reading EXA_METADATA")
-- Execute query and get cursor
cursor = assert(connection:execute([[
    SELECT PARAM_NAME, PARAM_VALUE
    FROM EXA_METADATA
    WHERE PARAM_NAME LIKE 'max%'
    ORDER BY PARAM_NAME ASC
    LIMIT 5]]))

-- Define reusable table for storing row data
local row = {}
-- Fetch first row
row = cursor:fetch(row, "a")
local index = 1
-- Iterate over rows
while row ~= nil do
    log.info("  - row %d: %s = '%s'", index, row['PARAM_NAME'],
             row['PARAM_VALUE'])
    row = cursor:fetch(row, "a")
    index = index + 1
end

-- Cursor is closed automatically at this point by last call to fetch()

--
-- Close the connection
--
if connection:close() then
    log.info("Connection closed successfully")
else
    error("Failed to close connection")
end

--
-- Close the environment
--
if environment:close() then
    log.info("Environment closed successfully")
else
    error("Failed to close environment")
end
