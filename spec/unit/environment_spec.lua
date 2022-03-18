---@diagnostic disable: undefined-global
-- luacheck: globals describe, it, before_each, after_each
require("busted.runner")()

local mockagne = require("mockagne")
local websocket_mock = mock(require("exasol_websocket"), true)
package.preload["exasol_websocket"] = function () return websocket_mock end

local driver = require("luasqlexasol")
local config = require("config")

local connection_params = config.get_connection_params()

describe("Environment", function ()
    local env = nil
    before_each(function ()
        env = driver.exasol()
    end)
    after_each(function ()
        env:close()
        env=nil
    end)

    it("connects to a db", function ()
        local conn, err = env:connect("host:1234", "user", "password")
        assert.is_nil(error)
        assert.is_not_nil(conn)
    end)
end)