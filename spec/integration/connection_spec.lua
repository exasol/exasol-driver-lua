---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasqlexasol")
local config = require("config")

config.configure_logging()

describe("Connection", function()
    local env = nil
    local connection = nil
    before_each(function()
        env = driver.exasol()
        local connection_params = config.get_connection_params()
        connection = assert(env:connect(connection_params.source_name, connection_params.user,
                                        connection_params.password))
    end)
    after_each(function()
        if connection then connection:close() end
        env:close()
        env = nil
        connection = nil
    end)

    it("executes a query", function()
        local cursor = assert(connection:execute("select 1"))
        assert.is_same({1}, cursor:fetch())
        assert.is_nil(cursor:fetch())
    end)

    it("returns error when executing an invalid query", function()
        local cursor, err = connection:execute("select")
        assert.is_nil(cursor)
        assert.matches("E%-EDL%-6: Error executing statement 'select': E%-EDL%-10: Received DB status 'error' " ..
                               "with code 42000: 'syntax error, unexpected ';'", tostring(err))
    end)

    it("fails executing a query when already closed", function()
        connection:close()
        assert.has_error(function() connection:execute("select 1") end, "E-EDL-12: Connection already closed")
    end)

    it("doesn't fail when closing a closed connection", function()
        connection:close()
        connection:close()
    end)

    it("closes cursors", function()
        local cursor = assert(connection:execute("select 1"))
        connection:close()
        assert.has_error(function() cursor:fetch() end,
                         "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
    end)
end)

