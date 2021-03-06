require("busted.runner")()
local driver = require("luasql.exasol")
local config = require("config")

config.configure_logging()

describe("Smoketest", function()
    local env = nil

    before_each(function()
        env = driver.exasol()
    end)

    after_each(function()
        assert.is_true(env:close())
        env = nil
    end)

    it("#smoketest", function()
        assert.error_matches(function()
            env:connect("invalid:8563", "user", "password")
        end, "E%-EDL%-1: Error connecting to 'wss://invalid:8563': " .. "'Connection to invalid:8563 failed:.*")
    end)
end)
