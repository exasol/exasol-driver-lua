require("busted.runner")()
local driver = require("luasql.exasol")
local config = require("config")

config.configure_logging()
local connection_params = config.get_connection_params()

--- Check if a string starts with a given prefix.
local function string_starts_with(string, prefix)
    return string.sub(string, 1, string.len(prefix)) == prefix
end

describe("Environment", function()
    local env = nil

    before_each(function()
        env = driver.exasol()
    end)

    after_each(function()
        if not env.closed then
            assert.is_true(env:close(), "Not all connections were closed during test cleanup")
        end
        env = nil
    end)

    it("throws an error when connecting to an invalid host", function()
        assert.error_matches(function()
            env:connect("invalid:8563", "user", "password")
        end, "E%-EDL%-1: Error connecting to 'wss://invalid:8563': " .. "'Connection to invalid:8563 failed:.*")
    end)

    it("throws an error when connecting to an invalid port", function()
        assert.error_matches(function()
            env:connect("localhost:1234", "user", "password")
        end, "E%-EDL%-1: Error connecting to 'wss://localhost:1234': " .. "'Connection to localhost:1234 failed:.*")
    end)

    it("returns an error when connecting with wrong credendials", function()
        local conn, err = env:connect(connection_params.source_name, "wrong-user", "password")
        assert.is_nil(conn)
        assert.is_not_nil(err)
        local error_message = tostring(err)
        if string_starts_with(error_message, "E-EDL-16") then
            assert.matches("E%-EDL%-16: Login failed: 'E%-EDL%-10: Received DB status 'error' with code 08004: "
                                   .. "'Connection exception %- authentication failed.''.*", error_message)
        else
            -- This alternative error occurs sporadically when the database closes the Websocket
            -- before we can read the response.
            assert.matches("E%-EDL%-19: Login failed because socket is closed%. Probably credentials are wrong: "
                                   .. "'E%-EDL%-4: Error receiving data while waiting for response for .*s: 'closed'.*",
                           error_message)
        end
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
        assert.has_error(function()
            env:connect("source", "user", "password")
        end, "E-EDL-21: Attempt to connect using an environment that is already closed")
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
