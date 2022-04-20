---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local cjson = require("cjson")
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

    describe("fetch()", function()
        -- [itest -> dsn~luasql-cursor-fetch~0]
        it("returns simple result", function()
            local cursor = assert(connection:execute("select 1"))
            assert.is_same({1}, cursor:fetch())
            assert.is_nil(cursor:fetch())
        end)

        it("automatically closes cursor when fetch() is called after last row", function()
            local cursor = assert(connection:execute("select 1"))
            assert.is_same({1}, cursor:fetch())
            assert.is_false(cursor.closed)
            assert.is_nil(cursor:fetch())
            assert.is_true(cursor.closed)
        end)

        it("raises error when calling fetch() twice after last row", function()
            local cursor = assert(connection:execute("select 1"))
            assert.is_same({1}, cursor:fetch())
            assert.is_nil(cursor:fetch())
            assert.error(function() cursor:fetch() end,
                         "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
        end)

        it("returns NULL as cjson.null", function()
            local cursor = assert(connection:execute("select 1, null"))
            assert.is_same({1, cjson.null}, cursor:fetch())
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

        it("returns table with alphanumeric indices", function()
            local cursor = assert(connection:execute("select 1 as a, 2 as b"))
            assert.is_same({A = 1, B = 2}, cursor:fetch({}, "a"))
            assert.is_nil(cursor:fetch())
        end)

        it("returns table with numeric indices", function()
            local cursor = assert(connection:execute("select 1 as a, 2 as b"))
            assert.is_same({1, 2}, cursor:fetch({}, "n"))
            assert.is_nil(cursor:fetch())
        end)

        it("uses numeric indices by default", function()
            local cursor = assert(connection:execute("select 1 as a, 2 as b"))
            assert.is_same({1, 2}, cursor:fetch({}))
            assert.is_nil(cursor:fetch())
        end)

        it("returns multiple columns in multiple rows", function()
            local cursor = assert(connection:execute(
                                          "select t.* from (values (1, 'a'), (2, 'b'), (3, 'c')) as t(num, txt)"))
            assert.is_same({1, "a"}, cursor:fetch())
            assert.is_same({2, "b"}, cursor:fetch())
            assert.is_same({3, "c"}, cursor:fetch())
            assert.is_nil(cursor:fetch())
        end)

        -- [itest -> dsn~luasql-cursor-close~0]
        it("fails when cursor is already closed", function()
            local cursor = assert(connection:execute("select 1"))
            cursor:close()
            assert.has_error(function() cursor:fetch() end,
                             "E-EDL-13: Cursor closed while trying to fetch datasets from cursor")
        end)
    end)

    describe("close()", function()
        it("doesn't fail when called twice", function()
            local cursor = assert(connection:execute("select 1"))
            cursor:close()
            cursor:close()
        end)
    end)
end)
