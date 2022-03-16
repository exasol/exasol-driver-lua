---
-- This module allows accessing an Exasol database.
--
-- @module M
--
local M = {
    VERSION = "0.1.0",
}

local environment = require("environment")
local log = require("remotelog")

---
-- Create a new environment.
--
-- @return created object
--
function M.exasol()
    log.trace("Created new luasql.exasol environment")
    return environment:new()
end

return M
