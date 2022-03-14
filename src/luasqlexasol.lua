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
function M.exasol(options)
    options = options or {}
    local log_level = string.upper(options.log_level) or "INFO"
    log.init().set_level(log_level)
    log.set_client_name("Exasol driver for Lua")
    log.trace("Created new luasql.exasol environment, log level = %s", log_level)
    return environment:new()
end

return M
