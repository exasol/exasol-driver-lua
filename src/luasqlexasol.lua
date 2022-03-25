--- This module allows accessing an Exasol database.
-- @module M
local M = {VERSION = "0.1.0"}

local Environment = require("environment")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")

--- Create a new environment that allows connecting to an Exasol database.
--- @return Environment environment new environment
--- [impl -> dsn~luasql-entry-point~0]
function M.exasol()
    log.trace("Created new luasql.exasol environment")
    return Environment:new()
end

return M
