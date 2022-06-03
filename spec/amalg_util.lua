local constants = require("luasql.exasol.constants")
local log = require("remotelog")

local M = {}

local function get_rockspec_filename() --
    return string.format("exasol-driver-lua-%s.rockspec", constants.VERSION)
end

local function load_rockspec(path)
    path = path or get_rockspec_filename()
    local env = {}
    local rockspec_function = assert(loadfile(path, "t", env))
    rockspec_function()
    return env
end

local function get_driver_module_names()
    local rockspec = load_rockspec()
    local modules = {}
    for module_name, _ in pairs(rockspec.build.modules) do
        table.insert(modules, module_name)
    end
    return modules
end

local function amalgamate(lua_path, modules, script_path)
    local command = "LUA_PATH=" .. lua_path .. " amalg.lua --fallback"
    if script_path then
        command = command .. " --script=" .. script_path
    end
    command = command .. " " .. table.concat(modules, " ")
    log.debug("Running amalg command: %s", command)
    local file = io.popen(command, "r")
    local output = file:read("*all")
    file:close()
    return output
end

local function write_temp_file(content)
    if not content then
        return nil
    end
    local path = os.tmpname()
    local temp_file = assert(io.open(path, "w"))
    temp_file:write(content)
    temp_file:close()
    return path
end

local function get_lua_path()
    return "src/?.lua"
end

local function get_third_party_module_names()
    return {"remotelog", "exaerror", "message_expander"}
end

local function insert_all(target, list)
    for _, value in ipairs(list) do
        table.insert(target, value)
    end
end

local function concat_tables(list1, list2)
    local result = {}
    insert_all(result, list1)
    insert_all(result, list2)
    return result
end

function M.amalgamate_with_script(script_content)
    local modules = concat_tables(get_driver_module_names(), get_third_party_module_names())
    local script_path = write_temp_file(script_content)
    local lua_path = get_lua_path()
    local content = amalgamate(lua_path, modules, script_path)
    if script_path then
        assert(os.remove(script_path))
    end
    return content
end

return M
