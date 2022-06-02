require("busted.runner")()
local constants = require("luasql.exasol.constants")
local config = require("config")
config.configure_logging()

describe("Constants", function()
    describe("NULL", function()
        it("is a table", function()
            assert.is_same("table", type(constants.NULL))
        end)

        it("is not equal to other value", function()
            assert.is_false(constants.NULL == {})
        end)

        it("is equal to itself", function()
            assert.is_true(constants.NULL == constants.NULL)
        end)

        it("is read-only", function()
            assert.error(function()
                constants.NULL = "other value"
            end, "E-EDL-32: Attempt to update read-only table: tried to set key 'NULL' to value 'other value'")
        end)
    end)

    describe("VERSION", function()
        it("has type string", function()
            assert.same("string", type(constants.VERSION))
        end)

        it("is read-only", function()
            assert.error(function()
                constants.VERSION = "other value"
            end, "E-EDL-32: Attempt to update read-only table: tried to set " .. "key 'VERSION' to value 'other value'")
        end)
    end)
end)
