---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local websocket = require("websocket")
local ConnectionProperties = require("connection_properties")
local log = require("remotelog")
local config = require("config")
config.configure_logging()
local params<const> = config.get_connection_params()
local local_websocket_url<const> = "wss://" .. params.host .. ":" .. params.port
local ssl_negotion_failed_error<const> = string.format("E-EDL-1: Error connecting to '%s': 'Failed SSL negotation'",
                                                       local_websocket_url)

local function connect(properties, url)
    url = url or local_websocket_url
    properties = properties or {}
    local connection_properties = ConnectionProperties:create(properties)
    local sock = websocket.connect(url, connection_properties)
    finally(function() sock:close() end)
    return sock
end

local function assert_connect_successful(properties)
    local sock = connect(properties)
    assert.is_not_nil(sock)
    assert.is_false(sock.closed)
    local result = sock:send_raw('{"command": "login", "protocolVersion": 3}')
    assert.matches('.*"status":"ok".*', result)
end

local function assert_connect_fails(properties, expected_error)
    expected_error = expected_error or ssl_negotion_failed_error
    assert.error(function() connect(properties) end, expected_error)
end

describe("Websocket", function()
    it("connects with default properties", function() --
        assert_connect_successful()
    end)

    it("connects with tls_verify=none", function() --
        assert_connect_successful({tls_verify = "none"})
    end)

    describe("fails connection with tls_verify option", function()
        for _, tls_verify_option in ipairs({"invalid", "", "peer", "client_once", "fail_if_no_peer_cert"}) do
            it(string.format("value %q", tls_verify_option), function() --
                assert_connect_fails({tls_verify = tls_verify_option})
            end)
        end
    end)

    describe("connects with tls_protocol option", function()
        for _, tls_protocol_option in ipairs({"any", "tlsv1_2"}) do
            it(string.format("value %q", tls_protocol_option), function() --
                assert_connect_successful({tls_protocol = tls_protocol_option})
            end)
        end
    end)

    describe("fails connection with tls_protocol option", function()
        for _, tls_protocol_option in ipairs({"invalid", "", "tlsv1", "tlsv1_1", "tlsv1_3"}) do
            it(string.format("value %q", tls_protocol_option), function() --
                assert_connect_fails({tls_protocol = tls_protocol_option})
            end)
        end
    end)

    describe("connects with tls_options option", function()
        for _, tls_options in ipairs({
            "", "all", "no_tlsv1_1", "no_tlsv1_3", "no_tlsv1", "no_tlsv1_1,no_tlsv1_3,no_tlsv1"
        }) do
            it(string.format("value %q", tls_options),
               function() assert_connect_successful({tls_options = tls_options}) end)
        end
    end)

    describe("fails connection with tls_options option", function()
        for _, tls_options in ipairs({
            "no_tlsv1_2", "no_tlsv1_2,all", "no_tlsv1_2, all", "no_tlsv1_1,no_tlsv1_3, no_tlsv1"
        }) do
            it(string.format("value %q", tls_options), function()
                assert_connect_fails({tls_options = tls_options})
            end)
        end
    end)

    it("log available ssl configuration options, useful for debugging", function()
        local ssl = require("ssl")
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
