---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasqlexasol")
local config = require("config")

config.configure_logging()

describe("Environment", function()
    local env = nil
    before_each(function() env = driver.exasol() end)
    after_each(function()
        env:close()
        env = nil
    end)

    it("throws an error when connecting to an invalid host", function()
        assert.error_matches(function() env:connect("invalid:8563", "user", "password") end,
                             "E%-EDL%-1: Error connecting to 'wss://invalid:8563': " ..
                                     "'Connection to invalid:8563 failed:.*")
    end)
end)
