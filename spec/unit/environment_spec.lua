---@diagnostic disable: undefined-global
-- luacheck: globals describe, it, before_each, after_each
require("busted.runner")()

local exaerror = require("exaerror")
local websocket_stub = {}
local websocket_mock = mock(websocket_stub)
package.preload["exasol_websocket"] = function() return websocket_mock end

local function reset_websocket_stub()
    websocket_stub.connect = function() return websocket_stub end
    websocket_stub.send_login_command = function()
        return {
            publicKeyModulus = "C94863E5F0311566058D2BD99E97D45DDE8D15E77C8AF511E40035D0E23E9C1617080AAA816612A6D064727A90D7765B4E356F31D7A0DDEBE4DFEC124242EC64CFF38515C5380B604D879674911C3F1E14FD2CDC93503C80228AC5C89CD8202A413657563388B58A5D82D9FCACE8B20E13D403627C897EEDA6CEB9FB5AF79555",
            publicKeyExponent = "010001"
        }
    end
    websocket_stub.send_login_credentials = function() return {sessionId = "sessionId0"} end
    websocket_stub.send_disconnect = function() return nil end
    websocket_stub.close = function() end
end


local driver = require("luasqlexasol")
local config = require("config")

local connection_params = config.get_connection_params()

describe("Environment", function()
    local env = nil
    before_each(function()
        reset_websocket_stub()
        env = driver.exasol()
    end)
    after_each(function()
        env:close()
        env = nil
    end)

    it("connects to a db", function()
        local conn, err = env:connect("host:1234", "user", "password")
        assert.is_nil(err)
        assert.is_not_nil(conn)
    end)

    it("returns login error for failed login", function()
        websocket_stub.send_login_credentials = function()
            return nil, exaerror.create("mock error")
        end
        local conn, err = env:connect("host:1234", "user", "password")
        assert.is_nil(conn)
        assert.is.same([[E-EDL-16: Login failed: 'mock error'

Mitigations:

* Check the credentials you provided.]], tostring(err))
    end)

    it("returns login error for closed socket", function()
        websocket_stub.send_login_credentials = function()
            local err = exaerror.create("mock error")
            err.cause = "closed"
            return nil, err
        end
        local conn, err = env:connect("host:1234", "user", "password")
        assert.is_nil(conn)
        assert.is.same([[E-EDL-19: Login failed because socket is closed. Probably credentials are wrong: 'mock error'

Mitigations:

* Check the credentials you provided.]], tostring(err))
    end)
end)
