---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local driver = require("luasqlexasol")
local config = require("config")

config.configure_logging()

describe("Cursor", function()
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

    it("returns simple result", function()
        local cursor = assert(connection:execute("select 1"))
        assert.is_same({1}, cursor:fetch())
        assert.is_nil(cursor:fetch())
    end)

    it("returns empty result", function()
        local cursor = assert(connection:execute("select * from dual where 1 = 2"))
        assert.is_nil(cursor:fetch())
    end)

    it("returns multiple columns for single row", function()
        local cursor = assert(connection:execute("select 'a', 'b', 'c'"))
        assert.is_same({"a", "b", "c"}, cursor:fetch())
        assert.is_nil(cursor:fetch())
    end)

    it("returns multiple columns for multiple row", function()
        local cursor =
                assert(connection:execute("select t.* from (values (1, 'a'), (2, 'b'), (3, 'c')) as t(num, txt)"))
        assert.is_same({1, "a"}, cursor:fetch())
        assert.is_same({2, "b"}, cursor:fetch())
        assert.is_same({3, "c"}, cursor:fetch())
        assert.is_nil(cursor:fetch())
    end)

    it("fails fetching when curser is already closed", function()
        local cursor = assert(connection:execute("select 1"))
        cursor:close()
        assert.has_error(function() cursor:fetch() end,
                         "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
    end)

    it("doesn't fail when closing a closed cursor", function()
        local cursor = assert(connection:execute("select 1"))
        cursor:close()
        cursor:close()
    end)
end)
