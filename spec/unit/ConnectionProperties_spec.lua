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

    describe("fingerprint property", function()
        local EXPECTED_VALIDATION_ERROR<const> = "E-EDL-41: Parameter 'fingerprint' must be a "
                .. "64-digit hexadecimal SHA-256 fingerprint\n\nMitigations:\n\n"
                .. "* Use the SHA-256 fingerprint of the TLS peer certificate."

        -- [utest -> dsn~skip-certificate-fingerprint-verification~1]
        it("is absent by default", function()
            assert.is_nil(ConnectionProperties:create():get_fingerprint())
        end)

        -- [utest -> dsn~tls-certificate-fingerprint-pinning~1]
        it("normalizes upper-case hexadecimal input", function()
            local fingerprint = string.rep("AB", 32)
            local properties = ConnectionProperties:create({fingerprint = fingerprint})
            assert.is_same(string.rep("ab", 32), properties:get_fingerprint())
        end)

        -- [utest -> dsn~validate-certificate-fingerprint~1]
        for _, invalid_fingerprint in ipairs({"", string.rep("a", 63), string.rep("g", 64), 42}) do
            it("rejects invalid fingerprint " .. tostring(invalid_fingerprint), function()
                assert_validation_error({fingerprint = invalid_fingerprint},
                                        EXPECTED_VALIDATION_ERROR)
            end)
        end
    end)
end)
