---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()

local datahandler = require("WebsocketDatahandler")

describe("WebsocketDatahandler", function()
    local connection_stub = {}
    local handler = nil
    before_each(function() handler = datahandler:create() end)

    describe("handle_data()", function()

        it("ignores data when a websocket error was received", function()
            handler:handle_data(connection_stub, false, "msg")
            assert.is_nil(handler:get_data())
        end)

        it("ignores data when unexpected data was received", function()
            handler:handle_data(connection_stub, true, "msg")
            assert.is_nil(handler:get_data())
        end)

        it("does not expect more data after expected_data_received() was called", function()
            handler:expect_data()
            handler:handle_data(connection_stub, true, "msg")
            handler:expected_data_received()
            handler:handle_data(connection_stub, true, "unexpected")
            assert.is_same("msg", handler:get_data())
        end)
    end)

    describe("get_data()", function()
        it("returns nil when nothing is collected", function() assert.is_nil(handler:get_data()) end)

        it("returns data when expected data was received", function()
            handler:expect_data()
            handler:handle_data(connection_stub, true, "msg")
            assert.is_same("msg", handler:get_data())
        end)

        it("concatenates received data", function()
            handler:expect_data()
            handler:handle_data(connection_stub, true, "msg1")
            handler:handle_data(connection_stub, true, "msg2")
            handler:handle_data(connection_stub, true, "msg3")
            assert.is_same("msg1msg2msg3", handler:get_data())
        end)
    end)

    describe("has_received_data()", function()
        it("returns false when no message received", function() assert.is_false(handler:has_received_data()) end)
        it("returns true when messages received", function()
            handler:expect_data()
            handler:handle_data(connection_stub, true, "msg1")
            assert.is_true(handler:has_received_data())
        end)
    end)
end)
