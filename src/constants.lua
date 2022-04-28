local util = require("util")

--- This module contains constants used by the Exasol driver.
-- @module M
local M = {}

--- The version of this module
M.VERSION = "0.1.0"

--- The value returned by queries to indicate an SQL <code>NULL</code> value.
M.NULL = {}

return util.read_only(M)
