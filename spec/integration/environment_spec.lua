---@diagnostic disable: undefined-global
-- luacheck: globals describe, it, before_each, after_each
require("busted.runner")()
local driver = require("luasqlexasol")
local config = require("config")

config.configure_logging()
local connection_params = config.get_connection_params()

describe("Environment", function()
    local env = nil
    before_each(function() env = driver.exasol() end)
    after_each(function()
        env:close()
        env = nil
    end)

    --[=[
    it("throws an error when connecting to an invalid host", function()
        assert.has_error(function() env:connect("invalid:8563", "user", "password") end,
                         "E-EDL-1: Error connecting to 'wss://invalid:8563': 'Connection to invalid:8563 failed: host or service not provided, or not known'")
    end)

    it("throws an error when connecting to an invalid port", function()
        assert.has_error(function() env:connect("localhost:8563", "user", "password") end,
                         "E-EDL-1: Error connecting to 'wss://localhost:8563': 'Connection to localhost:8563 failed: connection refused'")
    end)

        --]=]
    it("returns an error when connecting with wrong credendials", function()
        local conn, err = env:connect(connection_params.source_name, "user", "password")
        assert.is_nil(conn)
        assert.is_same(
                [[E-EDL-16: Login failed: 'E-EDL-10: Received DB status 'error' with code 08004: 'Connection exception - authentication failed.''

Mitigations:

* Check the credentials you provided.]], tostring(err))
    end)

    it("connects with valid credendials", function()
        local conn, err = env:connect(connection_params.source_name, connection_params.user, connection_params.password)
        assert.is_nil(err)
        assert.is_not_nil(conn)
    end)

    it("fails connecting when already closed", function()
        env:close()
        assert.has_error(function() env:connect("source", "user", "password") end,
                         "E-EDL-21: Attempt to connect using an environment that is already closed")
    end)

    it("closes connection when closing an environment", function()
        print("Connecting...")
        local conn, err = env:connect(connection_params.source_name, connection_params.user, connection_params.password)
        assert.is_nil(err)
        print("Closing ...")
        env:close()
        assert.has_error(function() conn:execute("select 1") end, "E-EDL-12: Connection already closed")
    end)
end)
