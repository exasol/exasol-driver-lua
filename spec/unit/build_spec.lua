require("busted.runner")()
local constants = require("luasql.exasol.constants")
local config = require("config")
config.configure_logging()

describe("Build setup", function()
    local function load_rockspec(path)
        local env = {}
        local rockspec_function = assert(loadfile(path, "t", env))
        rockspec_function()
        return env
    end

    local function get_rockspec_filename() --
        return string.format("luasql-exasol-%s.rockspec", constants.VERSION)
    end

    describe("Rockspec file", function()
        it("has correct filename", function()
            local filename = get_rockspec_filename()
            local file = io.open(filename, "r")
            finally(function()
                file:close()
            end)
            assert.is_not_nil(file, "Expected rockspec to have filename " .. filename)
        end)

        describe("version field", function()
            it("has type string", function()
                local rockspec = load_rockspec(get_rockspec_filename())
                assert.is_same("string", type(rockspec.version), "Rockspec version must be string")
            end)

            it("is equal to constants.VERSION", function()
                local rockspec = load_rockspec(get_rockspec_filename())
                assert.is_same(constants.VERSION, rockspec.version,
                               "Rockspec version must be equal to version in constants.lua")
            end)
        end)
    end)
end)
