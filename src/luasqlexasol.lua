--- This module allows accessing an Exasol database.
-- @module luasqlexasol
local luasqlexasol = {}

local Environment = require("environment")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local constants = require("constants")
local util = require("util")

--- The version of this module
luasqlexasol.VERSION = constants.VERSION

--- The value returned by queries to indicate an SQL `NULL` value.
-- Note: we need to define the NULL constant in separate module constants to break cyclic dependencies.
luasqlexasol.NULL = constants.NULL

--- Create a new environment that allows connecting to an Exasol database.
-- @treturn Environment new environment
function luasqlexasol.exasol()
    -- [impl -> dsn~luasql-entry-point~0]
    log.trace("Created new luasql.exasol environment")
    return Environment:new()
end

return util.read_only(luasqlexasol)
