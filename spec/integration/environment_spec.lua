---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasqlexasol")
local config = require("config")

config.configure_logging()
local connection_params = config.get_connection_params()

describe("Environment", function()
    local env = nil

    before_each(function() env = driver.exasol() end)

    after_each(function()
        if not env.closed then assert.is_true(env:close(), "Not all connections where closed") end
        env = nil
    end)

    it("throws an error when connecting to an invalid host", function()
        assert.error_matches(function() env:connect("invalid:8563", "user", "password") end,
                             "E%-EDL%-1: Error connecting to 'wss://invalid:8563': " ..
                                     "'Connection to invalid:8563 failed:.*")
    end)

    it("throws an error when connecting to an invalid port", function()
        assert.error_matches(function() env:connect("localhost:1234", "user", "password") end,
                             "E%-EDL%-1: Error connecting to 'wss://localhost:1234': " ..
                                     "'Connection to localhost:1234 failed:.*")
    end)

    it("returns an error when connecting with wrong credendials", function()
        local conn, err = env:connect(connection_params.source_name, "user", "password")
        assert.is_nil(conn)
        assert.matches("E%-EDL%-16: Login failed: 'E%-EDL%-10: Received DB status 'error' with code 08004: " ..
                               "'Connection exception %- authentication failed.''.*", tostring(err))
    end)

    -- [itest -> dsn~luasql-environment-connect~0]
    -- [itest -> dsn~luasql-entry-point~0]
    it("connects with valid credendials", function()
        local conn, err = env:connect(connection_params.source_name, connection_params.user, connection_params.password)
        assert.is_nil(err)
        assert.is_not_nil(conn)
        conn:close()
    end)

    it("fails connecting when already closed", function()
        env:close()
        assert.has_error(function() env:connect("source", "user", "password") end,
                         "E-EDL-21: Attempt to connect using an environment that is already closed")
    end)

    -- [itest -> dsn~luasql-environment-close~0]
    it("does not close a connection when closing an environment", function()
        local conn = assert(env:connect(connection_params.source_name, connection_params.user,
                                        connection_params.password))
        env:close()
        local cur = conn:execute("select 1")
        assert.is_not_nil(cur)
        cur:close()
        conn:close()
    end)
end)
