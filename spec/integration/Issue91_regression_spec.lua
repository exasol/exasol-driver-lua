-- This is a regression test for exasol/exosol-driver-lua#91
-- https://github.com/exasol/exasol-driver-lua/issues/91
--
-- At the switch from Exasol 7.1 to 8 the test of the drivers broke (first observed in a test
-- against Exasol 8.23.0. Under certain conditions the tests trigger a message timeout after
-- 5 seconds.
--
-- The test below is the minimal implementation that triggers the issue.

require("busted.runner")()
local driver = require("luasql.exasol")
local config = require("config")

describe("Issue91", function()
    local connection_params = config.get_connection_params()
    local env = driver.exasol()

    local function create_connection()
        return assert(env:connect(connection_params.source_name, connection_params.user, connection_params.password))
    end

    it("must not raise message timeout error", function()
        local connectionA = create_connection()
        -- If you don't use a cursor here and then immediately close the connection, the problem can
        -- be triggered with the next new connection.
        connectionA:close()
        local connectionB = create_connection()
        finally(function()
            if(not connectionB.closed) then
                print("Cleaning up remaining connection after failure.")
                connectionB:close()
            end
        end)
        local cursor = assert(connectionB:execute("SELECT 1")) -- ← here is where the error is raised.
        cursor:close()
    end)
end)
