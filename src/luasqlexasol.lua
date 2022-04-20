local exaerror = require("exaerror")
local Environment = require("environment")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")

--- This module allows accessing an Exasol database.
-- @module M
local M = {}

---
M.VERSION = "0.1.0"

--- The value returned by queries to indicate an SQL <code>NULL</code> value.
M.NULL = {}

--- Create a new environment that allows connecting to an Exasol database.
--- @return Environment new environment
--- [impl -> dsn~luasql-entry-point~0]
function M.exasol()
    log.trace("Created new luasql.exasol environment")
    return Environment:new()
end

--- Make a table read-only be wrapping it in a proxy that raises an error for modifications.
--- See https://www.lua.org/pil/13.4.5.html for details.
local function read_only(table)
    local proxy = {}
    local metatable = {
        __index = table,
        __newindex = function(t, k, v)
            exaerror.create("E-EDL-32", "Attempt to update a read-only table"):raise(3)
        end
    }
    setmetatable(proxy, metatable)
    return proxy
end

return read_only(M)
