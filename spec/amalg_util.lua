local constants = require("luasql.exasol.constants")

local M = {}

local function get_rockspec_filename() --
    return string.format("exasol-driver-lua-%s.rockspec", constants.VERSION)
end

local function load_rockspec(path)
    local env = {}
    local rockspec_function = assert(loadfile(path, "t", env))
    rockspec_function()
    return env
end

local function get_module_names()
    local path = get_rockspec_filename()
    local rockspec = load_rockspec(path)
    local modules = {}
    for module_name, _ in pairs(rockspec.build.modules) do table.insert(modules, module_name) end
    return modules
end

--  amalg.lua --debug $script_arg --output "$output_file" $module_names
local function amalgamate(lua_path, modules, script_path)
    local command = "LUA_PATH=" .. lua_path .. " amalg.lua --debug"
    if script_path then command = command .. " --script=" .. script_path end
    command = command .. " " .. table.concat(modules, " ")
    local file = io.popen(command, "r")
    local output = file:read("*all")
    file:close()
    return output
end

local function write_temp_file(content)
    if not content then return nil end
    local path = os.tmpname()
    local temp_file = assert(io.open(path, "w"))
    temp_file:write(content)
    temp_file:close()
    return path
end

local function get_lua_path() return "src/?.lua" end

function M.amalgamate_with_script(script_content)
    local modules = get_module_names()
    local script_path = write_temp_file(script_content)
    local lua_path = get_lua_path()
    local content = amalgamate(lua_path, modules, script_path)
    if script_path then assert(os.remove(script_path)) end
    return content
end

local function read_file(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*all")
    file:close()
    return content
end

return M
