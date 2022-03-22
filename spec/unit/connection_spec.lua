---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasqlexasol")

describe("Connection", function()
    local env = nil
    before_each(function() env = driver.exasol() end)
    after_each(function()
        env:close()
        env = nil
    end)
end)
