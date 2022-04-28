local Environment = require("environment")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local constants = require("constants")
local util = require("util")

--- This module allows accessing an Exasol database.
-- @module M
local M = {}

--- The version of this module
M.VERSION = constants.VERSION

--- The value returned by queries to indicate an SQL <code>NULL</code> value.
-- Note: we need to define the NULL constant in separate module constants to break cyclic dependencies.
M.NULL = constants.NULL

--- Create a new environment that allows connecting to an Exasol database.
-- @return Environment new environment
-- [impl -> dsn~luasql-entry-point~0]
function M.exasol()
    log.trace("Created new luasql.exasol environment")
    return Environment:new()
end

return util.read_only(M)
