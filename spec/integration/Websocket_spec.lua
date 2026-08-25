require("busted.runner")()
local websocket = require("luasql.exasol.Websocket")
local ConnectionProperties = require("luasql.exasol.ConnectionProperties")
local log = require("remotelog")
local socket = require("socket")
local ssl = require("ssl")
local config = require("config")
config.configure_logging()
local params<const> = config.get_connection_params()
local local_websocket_url<const> = "wss://" .. params.host .. ":" .. params.port

local function get_connection_error(error_details)
    return string.format("E-EDL-1: Error connecting to '%s': '%s'", local_websocket_url, error_details)
end

local function get_ssl_socket_creation_error(error_details)
    return get_connection_error(string.format("Failed to create SSL socket: '%s'", error_details))
end

local ssl_negotiation_failed_error<const> = get_connection_error("Failed SSL/TLS negotiation")

local function connect(properties, url)
    url = url or local_websocket_url
    properties = properties or {}
    local connection_properties = ConnectionProperties:create(properties)
    local sock = websocket.connect(url, connection_properties)
    finally(function()
        sock:close()
    end)
    return sock
end

local function assert_connect_successful(properties, url)
    local sock = connect(properties, url)
    assert.is_not_nil(sock)
    assert.is_false(sock.closed)
    local result = sock:send_raw('{"command": "login", "protocolVersion": 3}')
    assert.matches('.*"status":"ok".*', result)
end

local function assert_connect_fails(properties, expected_error)
    assert.error(function()
        connect(properties)
    end, expected_error)
end

local function get_tls_peer_fingerprint()
    local tcp_socket = assert(socket.tcp())
    assert(tcp_socket:connect(params.host, params.port))
    local tls_socket = assert(ssl.wrap(tcp_socket, {
        mode = "client",
        verify = "none",
        protocol = "tlsv1_2",
        options = {"all"}
    }))
    assert(tls_socket:dohandshake())
    local fingerprint = assert(tls_socket:getpeercertificate():digest("sha256"))
    tls_socket:close()
    return fingerprint
end

describe("Websocket", function()
    -- [itest -> dsn~skip-certificate-fingerprint-verification~1]
    it("connects with default properties", function() --
        assert_connect_successful()
    end)

    describe("with certificate fingerprint pinning", function()
        -- [itest -> dsn~tls-certificate-fingerprint-pinning~1]
        it("connects with the matching peer certificate fingerprint", function()
            assert_connect_successful({fingerprint = get_tls_peer_fingerprint()})
        end)

        -- [itest -> dsn~reject-mismatching-certificate-fingerprint~1]
        it("rejects a mismatching fingerprint without exposing the configured fingerprint", function()
            local fingerprint = string.rep("0", 64)
            local success, err = pcall(connect, {fingerprint = fingerprint})
            assert.is_false(success)
            local error_message = tostring(err)
            assert.matches("E%-EDL%-43", error_message)
            assert.not_matches(fingerprint, error_message)
        end)
    end)

    describe("with option tls_verify option", function()
        it("succeeds for value 'none'", function() --
            assert_connect_successful({tls_verify = "none"})
        end)

        describe("fails SSL negotiation for valid value", function()
            for _, tls_verify_option in ipairs({"peer", "client_once", "fail_if_no_peer_cert"}) do
                it(string.format("%q", tls_verify_option), function()
                    assert_connect_fails({tls_verify = tls_verify_option}, ssl_negotiation_failed_error)
                end)
            end
        end)

        describe("fails for invalid values", function()
            for _, tls_verify_option in ipairs({"invalid", ""}) do
                it(string.format("%q", tls_verify_option), function()
                    assert_connect_fails({tls_verify = tls_verify_option}, get_ssl_socket_creation_error(
                            "invalid verify option (" .. tls_verify_option .. ")"))
                end)
            end
        end)
    end)

    describe("with tls_protocol option", function()
        describe("connects successfully for Exasol-supported protocol version:", function()
            local supported_protocols = {"any", "tlsv1_2", "tlsv1_3"}
            for _, tls_protocol_option in ipairs(supported_protocols) do
                it(string.format("value %q", tls_protocol_option), function()
                    assert_connect_successful({tls_protocol = tls_protocol_option})
                end)
            end
        end)

        describe("fails SSL negotiation for TLS protocol version that is not supported by Exasol:", function()
            local unsupported_protocols = {"tlsv1", "tlsv1_1"}
            for _, tls_protocol_option in ipairs(unsupported_protocols) do
                it(string.format("%q", tls_protocol_option), function()
                    assert_connect_fails({tls_protocol = tls_protocol_option}, ssl_negotiation_failed_error)
                end)
            end
        end)

        describe("fails for invalid value", function()
            for _, tls_protocol_option in ipairs({"invalid", ""}) do
                it(string.format("%q", tls_protocol_option), function()
                    assert_connect_fails({tls_protocol = tls_protocol_option}, get_ssl_socket_creation_error(
                            "invalid protocol (" .. tls_protocol_option .. ")"))
                end)
            end
        end)
    end)

    describe("with tls_options", function()
        describe("connects successfully for Exasol-supported protocol version:", function()
            for _, tls_options in ipairs({
                "", "all", "no_tlsv1_1", "no_tlsv1_3", "no_tlsv1", "no_tlsv1_1,no_tlsv1_3,no_tlsv1"
            }) do
                it(string.format("%q", tls_options), function()
                    assert_connect_successful({tls_options = tls_options})
                end)
            end
        end)

        describe("fails SSL negotiation for valid value", function()
            for _, tls_options in ipairs({"no_tlsv1_2", "no_tlsv1_2,all", "no_tlsv1_2,all"}) do
                it(string.format("%q", tls_options), function()
                    assert_connect_fails({tls_options = tls_options}, ssl_negotiation_failed_error)
                end)
            end
        end)

        describe("fails for invalid value", function()
            for _, tls_options in ipairs({"invalid"}) do
                it(string.format("%q", tls_options), function()
                    assert_connect_fails({tls_options = tls_options},
                                         get_ssl_socket_creation_error("invalid option (" .. tls_options .. ")"))
                end)
            end
        end)

        it("fails with invalid value for comma separated list with space", function()
            assert_connect_fails({tls_options = "no_tlsv1_2, all"},
                                 get_ssl_socket_creation_error("invalid option ( all)"))
        end)
    end)

    teardown(function()
        -- Log available SSL configuration options, useful for debugging
        log.debug("Available ssl configuration options:")
        for key, value in pairs(ssl.config.options) do --
            log.debug("ssl.config.options['%s'] = %s", key, value)
        end
        for key, value in pairs(ssl.config.capabilities) do
            log.debug("ssl.config.capabilities['%s'] = %s", key, value)
        end
        for key, value in pairs(ssl.config.protocols) do --
            log.debug("ssl.config.protocols['%s'] = %s", key, value)
        end
    end)
end)
