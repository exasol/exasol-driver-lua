---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()

local environment = require("luasql.exasol.Environment")
local config = require("config")
config.configure_logging()

local websocket_stub = {}

local function reset_websocket_stub(stub)
    stub.connect = function()
        return stub
    end
    stub.send_login_command = function()
        return {
            publicKeyModulus = "C94863E5F0311566058D2BD99E97D45DDE8D15E77C8AF511E40035D0E23E9C1617080"
                    .. "AAA816612A6D064727A90D7765B4E356F31D7A0DDEBE4DFEC124242EC64CFF38515C5380B604D879674911C"
                    .. "3F1E14FD2CDC93503C80228AC5C89CD8202A413657563388B58A5D82D9FCACE8B20E13D403627C897EEDA6C"
                    .. "EB9FB5AF79555",
            publicKeyExponent = "010001"
        }
    end
    stub.send_login_credentials = function()
        return {sessionId = 12345}
    end
    stub.send_disconnect = function()
        return nil
    end
    stub.close = function()
    end
end

local exaerror = require("exaerror")

describe("Environment", function()
    local env = nil
    local websocket_mock = nil

    before_each(function()
        reset_websocket_stub(websocket_stub)
        websocket_mock = mock(websocket_stub, false)
        env = environment:new({exasol_websocket = websocket_mock})
    end)

    after_each(function()
        env:close()
        env = nil
    end)

    it("reports a version", function()
        local conn, err = env:connect("host:1234", "user", "password")
        assert.is_nil(err)
        assert.is_not_nil(conn)
    end)

    describe("connect()", function()

        it("connects to a db", function()
            local conn, err = env:connect("host:1234", "user", "password")
            assert.is_nil(err)
            assert.is_not_nil(conn)
        end)

        -- [utest -> dsn~luasql-environment-connect~0]
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

        -- [utest -> dsn~luasql-environment-connect~0]
        it("returns login error for closed socket", function()
            websocket_stub.send_login_credentials = function()
                local err = exaerror.create("mock error")
                err.cause = "closed"
                return nil, err
            end
            local conn, err = env:connect("host:1234", "user", "password")
            assert.is_nil(conn)
            assert.is.same(
                    [[E-EDL-19: Login failed because socket is closed. Probably credentials are wrong: 'mock error'

Mitigations:

* Check the credentials you provided.]], tostring(err))
        end)

        it("raises error when connection is closed", function()
            env:close()
            assert.has_error(function()
                env:connect("host:1234", "user", "password")
            end, "E-EDL-21: Attempt to connect using an environment that is already closed")
        end)
    end)

    describe("close()", function()
        it("returns true if called once", function()
            assert.is_true(env:close())
        end)

        it("returns false if called twice", function()
            env:close()
            assert.is_false(env:close())
        end)
        it("returns false if an open connection exists", function()
            assert(env:connect("host:1234", "user", "password"))
            assert.is_false(env:close())
        end)

        it("returns true if no connection exists", function()
            assert.is_true(env:close())
        end)

        it("returns true if two of two connections are closed", function()
            local con1 = assert(env:connect("host1:1234", "user1", "password1"))
            local con2 = assert(env:connect("host2:1234", "user2", "password2"))
            con1:close()
            con2:close()
            assert.is_true(env:close())
        end)

        it("returns false if one of two connections is closed", function()
            local con1 = assert(env:connect("host1:1234", "user1", "password1"))
            assert(env:connect("host2:1234", "user2", "password2"))
            con1:close()
            assert.is_false(env:close())
        end)

        it("does not close the websocket when no connection exists", function()
            env:close()
            assert.stub(websocket_mock.close).was.not_called()
        end)
    end)
end)
