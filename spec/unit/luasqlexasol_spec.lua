---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local config = require("config")
config.configure_logging()

local log_mock = mock(require("remotelog"), true)
package.preload["remotelog"] = function() return log_mock end

local driver = require("luasqlexasol")

describe("Entry point", function()

    it("creates an environment", function()
        local env = driver.exasol()
        finally(function() env:close() end)
        assert.is_not_nil(env)
    end)

    it("creates a new environment for each call", function()
        local env1 = driver.exasol()
        local env2 = driver.exasol()
        finally(function()
            env1:close()
            env2:close()
        end)
        assert.not_equal(env1, env2)
    end)

    -- [utest -> dsn~logging-with-remotelog~1]
    it("uses remotelog",
       function() assert.spy(log_mock.trace).was.called_with("Created new luasql.exasol environment") end)

    describe("NULL", function()
        it("is read-only", function()
            assert.error(function() driver.NULL = "other value" end, "E-EDL-32: Attempt to update a read-only table")
        end)

        it("is a table", function()
            assert.is_same("table", type(driver.NULL))
        end)

        it("is not equal to other value", function()
            assert.is_false(driver.NULL == {})
        end)

        it("is equal to itself", function()
            assert.is_true(driver.NULL == driver.NULL)
        end)
    end)

    describe("VERSION", function()
        it("has type string", function()
            assert.is_not_nil(driver.VERSION)
            assert.same("string", type(driver.VERSION))
        end)

        it("is read-only", function()
            assert.error(function() driver.VERSION = "other value" end, "E-EDL-32: Attempt to update a read-only table")
        end)
    end)
end)
