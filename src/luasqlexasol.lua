---
-- This module allows accessing an Exasol database.
--
-- @module M
--
local M = {VERSION = "0.1.0"}

local environment = require("environment")
local log = require("remotelog")

---
-- Create a new environment.
--
-- @return created object
--
function M.exasol(options)
    options = options or {}
    local log_level = options.log_level and string.upper(options.log_level)
    if log_level then 
        log.init().set_level(log_level)
        log.trace("Set log level to $s", log_level)
    end
    log.trace("Created new luasql.exasol environment")
    return environment:new()
end

return M
