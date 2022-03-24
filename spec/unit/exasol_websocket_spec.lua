---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local cjson = require("cjson")
local match = require("luassert.match")
require("assertions")

local exasol_websocket = require("exasol_websocket")
local config = require("config")
config.configure_logging()

describe("ExasolWebsocket", function()
    local exa_socket = nil
    local socket_mock = nil
    local send_raw_response = nil
    local send_raw_error = nil

    local function simulate_socket_error(err)
        send_raw_response = nil
        send_raw_error = err
    end

    local function simulate_response_string(raw_response)
        send_raw_response = raw_response
        send_raw_error = nil
    end

    local function simulate_response(raw_response) simulate_response_string(cjson.encode(raw_response)) end

    local function simulate_ok_response(response_data)
        simulate_response({status = "ok", responseData = response_data})
    end

    before_each(function()
        local socket_stub = {
            close = function() end,
            send_raw = function(self, raw_payload, ignore_response) return send_raw_response, send_raw_error end
        }
        socket_mock = mock(socket_stub, false)
        exa_socket = exasol_websocket._create(socket_mock)
    end)

    after_each(function()
        exa_socket:close()
        exa_socket = nil
    end)

    local function assert_raw_send(expected_json, ignore_response)
        assert.stub(socket_mock.send_raw).was.called_with(match.is_table(), match.is_json(expected_json),
                                                          ignore_response)
    end

    it("throws error when trying to send command with closed socket", function()
        exa_socket:close()
        assert.has_error(function() exa_socket:send_disconnect() end,
                         [[E-EDL-22: Websocket already closed when trying to send payload '{"command":"disconnect"}']])
    end)

    describe("send_login_command()", function()

        it("throws error response is nil", function()
            simulate_response_string(nil)
            assert.error_matches(function() exa_socket:send_login_command() end,
                                 "E%-EDL%-2: Did not receive response for request payload.*")
        end)

        it("returns error when socket returns error", function()
            simulate_socket_error("mock error")
            local result, err = exa_socket:send_login_command()
            assert.is_nil(result)
            assert.is_same("mock error", tostring(err))
        end)

        it("sends login command", function()
            local response_data = {data = 1}
            simulate_ok_response(response_data)
            local result, err = exa_socket:send_login_command()
            assert.is_same(response_data, result)
            assert.is_nil(err)
            assert_raw_send('{"protocolVersion":3,"command":"login"}')
        end)

        it("returns error without details when it fails", function()
            simulate_response({status = "error status"})
            local result, err = exa_socket:send_login_command()
            assert.is_nil(result)
            assert.is_same("E-EDL-17: Received DB status 'error status' without exception details", tostring(err))
        end)

        it("returns error with nil details when it fails", function()
            simulate_response({status = "error status", exception = {}})
            local result, err = exa_socket:send_login_command()
            assert.is_nil(result)
            assert.is_same("E-EDL-10: Received DB status 'error status' with code nil: 'nil'", tostring(err))
        end)

        it("returns error with details when it fails", function()
            simulate_response({status = "error status", exception = {sqlCode = "code", text = "text"}})
            local result, err = exa_socket:send_login_command()
            assert.is_nil(result)
            assert.is_same("E-EDL-10: Received DB status 'error status' with code code: 'text'", tostring(err))
        end)

    end)

    describe("send_login_credentials", function()

        it("sends login credentials command", function()
            local response_data = {data = 1}
            simulate_ok_response(response_data)
            local result, err = exa_socket:send_login_credentials("user", "password")
            assert.is_same(response_data, result)
            assert.is_nil(err)
            assert_raw_send('{"password":"password","username":"user","useCompression":false}')
        end)

        it("returns error when sending login credentials fails", function()
            simulate_response({status = "error status", exception = {sqlCode = "code", text = "text"}})
            local result, err = exa_socket:send_login_credentials("user", "password")
            assert.is_same("E-EDL-10: Received DB status 'error status' with code code: 'text'", tostring(err))
            assert.is_nil(result)
        end)
    end)

    describe("send_login_credentials()", function()
        it("sends execute command", function()
            local response_data = {data = 1}
            simulate_ok_response(response_data)
            local result, err = exa_socket:send_execute("statement")
            assert.is_same(response_data, result)
            assert.is_nil(err)
            assert_raw_send('{"sqlText":"statement","command":"execute","attributes":{}}')
        end)

        it("returns error when execution fails", function()
            simulate_response({status = "error status", exception = {sqlCode = "code", text = "text"}})
            local result, err = exa_socket:send_execute("statement")
            assert.is_same("E-EDL-10: Received DB status 'error status' with code code: 'text'", tostring(err))
            assert.is_nil(result)
        end)
    end)

    describe("send_disconnect()", function()
        it("sends disconnect command succeeds with response data", function()
            simulate_ok_response({data = 1})
            local err = exa_socket:send_disconnect()
            assert.is_nil(err)
            assert_raw_send('{"command":"disconnect"}', true)
        end)

        it("sends disconnect command succeeds without response data", function()
            simulate_ok_response(nil)
            local err = exa_socket:send_disconnect()
            assert.is_nil(err)
            assert_raw_send('{"command":"disconnect"}', true)
        end)

        it("returns no error when disconnect fails", function()
            simulate_response({status = "error status", exception = {sqlCode = "code", text = "text"}})
            local err = exa_socket:send_disconnect()
            assert.is_nil(err)
        end)
    end)
end)
