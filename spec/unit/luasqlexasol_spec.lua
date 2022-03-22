---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()

local log_mock = mock(require("remotelog"), true)
package.preload["remotelog"] = function() return log_mock end

local driver = require("luasqlexasol")

describe("Entry point", function()
    it("has a version", function()
        assert.is_not_nil(driver.VERSION)
        assert.same("string", type(driver.VERSION))
    end)

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

    it("uses remotelog",
       function() assert.spy(log_mock.trace).was.called_with("Created new luasql.exasol environment") end)
end)
