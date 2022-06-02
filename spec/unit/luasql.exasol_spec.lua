require("busted.runner")()
local constants = require("luasql.exasol.constants")
local config = require("config")
config.configure_logging()

local log_mock = mock(require("remotelog"), true)
package.preload["remotelog"] = function()
    return log_mock
end

local driver = require("luasql.exasol")

describe("Entry point", function()

    it("creates an environment", function()
        local env = driver.exasol()
        finally(function()
            env:close()
        end)
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
    it("uses remotelog", function()
        assert.spy(log_mock.trace).was.called_with("Created new luasql.exasol environment")
    end)

    describe("NULL", function()
        it("is a table", function()
            assert.is_same("table", type(driver.NULL))
        end)

        it("is not equal to other value", function()
            assert.is_false(driver.NULL == {})
        end)

        it("is equal to itself", function()
            assert.is_true(driver.NULL == driver.NULL)
        end)

        it("is equal to constant.NULL", function()
            assert.is_equal(constants.NULL, driver.NULL)
        end)

        it("is read-only", function()
            assert.error(function()
                driver.NULL = "other value"
            end, "E-EDL-32: Attempt to update read-only table: tried to set key 'NULL' to value 'other value'")
        end)
    end)

    describe("VERSION", function()
        it("has type string", function()
            assert.same("string", type(driver.VERSION))
        end)

        it("is read-only", function()
            assert.error(function()
                driver.VERSION = "other value"
            end, "E-EDL-32: Attempt to update read-only table: tried to set " .. "key 'VERSION' to value 'other value'")
        end)

        it("is equal to constant.VERSION", function()
            assert.is_equal(constants.VERSION, driver.VERSION)
        end)
    end)
end)
