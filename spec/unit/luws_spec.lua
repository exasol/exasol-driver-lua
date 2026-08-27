-- luacheck: globals wsopen wsreceive
require("busted.runner")()
local luws = require("luasql.exasol.luws")

describe("LuWS TLS certificate fingerprint verification", function()
    local expected_fingerprint = string.rep("a", 64)

    -- [utest -> dsn~tls-certificate-fingerprint-pinning~1]
    it("accepts a matching peer certificate fingerprint", function()
        local certificate = {digest = function() return string.upper(expected_fingerprint) end}
        assert.is_true(luws._verify_certificate_fingerprint({getpeercertificate = function() return certificate end},
                                                            expected_fingerprint))
    end)

    -- [utest -> dsn~reject-mismatching-certificate-fingerprint~1]
    it("rejects a mismatching peer certificate fingerprint", function()
        local certificate = {digest = function() return string.rep("b", 64) end}
        local socket = {getpeercertificate = function() return certificate end}
        local result, err = luws._verify_certificate_fingerprint(socket, expected_fingerprint)
        assert.is_nil(result)
        assert.is_same("E-EDL-43: TLS peer certificate fingerprint does not match the configured fingerprint", err)
    end)

    -- [utest -> dsn~reject-mismatching-certificate-fingerprint~1]
    it("rejects an unavailable peer certificate", function()
        local result, err = luws._verify_certificate_fingerprint({getpeercertificate = function() return nil end},
                                                                  expected_fingerprint)
        assert.is_nil(result)
        assert.is_same("E-EDL-42: TLS peer certificate is unavailable for fingerprint verification", err)
    end)

    -- [utest -> dsn~reject-mismatching-certificate-fingerprint~1]
    it("closes the TLS socket before WebSocket upgrade on mismatch", function()
        local original_ssl = package.loaded.ssl
        local tls_socket = {closed = false}
        tls_socket.settimeout = function() end
        tls_socket.dohandshake = function() return true end
        tls_socket.getpeercertificate = function()
            return {digest = function() return string.rep("b", 64) end}
        end
        function tls_socket:close()
            self.closed = true
        end
        package.loaded.ssl = {wrap = function() return tls_socket end}
        finally(function() package.loaded.ssl = original_ssl end)

        local tcp_socket = {
            setoption = function()
            end
        }
        local websocket, err = wsopen("wss://localhost:8563", function()
        end, {connect = function() return tcp_socket end, fingerprint = expected_fingerprint})

        assert.is_false(websocket)
        assert.is_same("E-EDL-43: TLS peer certificate fingerprint does not match the configured fingerprint", err)
        assert.is_true(tls_socket.closed)
    end)
end)

describe("LuWS receive timeout", function()
    -- [utest -> dsn~websocket-timeout-coordination~1]
    it("reports the LuWS wire-level timeout", function()
        local timeout_seconds = 5
        local websocket = {
            connected = true,
            lastMessage = 0,
            options = {receive_timeout = timeout_seconds},
            socket = {
                settimeout = function()
                end,
                receive = function()
                    return nil, "timeout", ""
                end
            },
            msghandler = function()
            end
        }

        local result, err = wsreceive(websocket)

        assert.is_nil(result)
        assert.is_same("LuWS wire-level timeout after 5s without a WebSocket message", err)
    end)
end)
