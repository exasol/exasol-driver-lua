require("busted.runner")()
local ConnectionProperties = require("luasql.exasol.ConnectionProperties")
local config = require("config")
config.configure_logging()

local function assert_validation_error(properties, expected_error)
    assert.error(function()
        ConnectionProperties:create(properties)
    end, expected_error)
end

describe("ConnectionProperties", function()
    describe("fetchsize_kib properties", function()
        local EXPECTED_VALIDATION_ERROR<const> = [[E-EDL-27: Parameter 'fetchsize_kib' must be greater than 0

Mitigations:

* Use a value greater than 0]]

        it("uses default value 128KiB", function()
            local props = ConnectionProperties:create()
            assert.is_same(128 * 1024, props:get_fetchsize_bytes())
            assert.is_same(131072, props:get_fetchsize_bytes())
        end)

        it("returns custom value 1KiB", function()
            local props = ConnectionProperties:create({fetchsize_kib = 1})
            assert.is_same(1024, props:get_fetchsize_bytes())
        end)

        it("returns fractions of KiB", function()
            local props = ConnectionProperties:create({fetchsize_kib = 0.5})
            assert.is_same(512, props:get_fetchsize_bytes())
        end)

        it("raises error for zero value", function()
            assert_validation_error({fetchsize_kib = 0}, EXPECTED_VALIDATION_ERROR)
        end)

        it("raises error for negative value", function()
            assert_validation_error({fetchsize_kib = -1}, EXPECTED_VALIDATION_ERROR)
        end)
    end)

    describe("tls_verify properties", function()
        it("has default value", function()
            local props = ConnectionProperties:create()
            assert.is_same("none", props:get_tls_verify())
        end)

        it("uses custom value", function()
            local props = ConnectionProperties:create({tls_verify = "myValue"})
            assert.is_same("myValue", props:get_tls_verify())
        end)
    end)

    describe("tls_protocol properties", function()
        it("has default value", function()
            local props = ConnectionProperties:create()
            assert.is_same("tlsv1_2", props:get_tls_protocol())
        end)

        it("uses custom value", function()
            local props = ConnectionProperties:create({tls_protocol = "myValue"})
            assert.is_same("myValue", props:get_tls_protocol())
        end)
    end)

    describe("tls_options properties", function()
        it("has default value", function()
            local props = ConnectionProperties:create()
            assert.is_same("all", props:get_tls_options())
        end)

        it("uses custom value", function()
            local props = ConnectionProperties:create({tls_options = "myValue"})
            assert.is_same("myValue", props:get_tls_options())
        end)
    end)
end)
