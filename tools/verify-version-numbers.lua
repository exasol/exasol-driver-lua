local function load_rockspec(path)
    local env = {}
    local rockspec_function = assert(loadfile(path, "t", env))
    rockspec_function()
    return env
end

local function load_constants(path)
    local env = {require = function() return {read_only = function(arg) return arg end} end}
    local module = assert(loadfile(path, "t", env))
    return module()
end

if #arg ~= 1 then error(string.format("Expected 1 argument but got %d: %s", #arg, table.concat(arg, " "))) end
local rockspec_path<const> = arg[1]
local constants_path<const> = "src/luasql/exasol/constants.lua"
local rockspec<const> = load_rockspec(rockspec_path)
local constants<const> = load_constants(constants_path)

local rockspec_version = rockspec.version

if type(rockspec_version) ~= "string" or #rockspec_version < 5 then
    error(string.format("Got invalid version from %s: %q", rockspec_path, rockspec_version))
end

if rockspec_version ~= constants.VERSION then
    error(string.format("Versions from %s (%q) and %s (%q) differ but must be equal", rockspec_path, rockspec_version,
                        constants_path, constants.VERSION))
else
    print(string.format("Versions from %s and %s are equal: %q", rockspec_path, constants_path, rockspec_version))
end
