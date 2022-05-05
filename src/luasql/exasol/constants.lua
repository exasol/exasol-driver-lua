--- This internal module contains constants used by the Exasol driver.
-- @module luasql.exasol.constants
local constants = {}

local util = require("luasql.exasol.util")

--- The version of this module
constants.VERSION = "0.1.0"

--- The value returned by queries to indicate an SQL `NULL` value.
constants.NULL = {}

return util.read_only(constants)
