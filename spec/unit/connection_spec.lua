---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local connection = require("connection")
local SESSION_ID = 12345

local websocket_stub = {}



describe("Connection", function()
    local conn = nil
    before_each(function() conn = connection:create(websocket_stub, SESSION_ID) end)
    after_each(function()
        env:close()
        conn = nil
    end)

    it("returns a cursor with results", function ()
        local cursor = assert(conn:execute("statement"))
        assert.is_same({1}, cursor:fetch())
        assert.is_same({1}, cursor:fetch())
    end)
end)
