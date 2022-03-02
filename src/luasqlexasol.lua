---
-- This module allows accessing an Exasol database.
--
-- @module M
--
local M = {
    VERSION = "0.1.0",
}

local environment = require("environment")

---
-- Create a new environment.
--
-- @return created object
--
function M.exasol()
    return environment:new()
end

return M
