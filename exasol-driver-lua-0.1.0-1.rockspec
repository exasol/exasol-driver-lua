rockspec_format = "3.0"

local tag = "0.1.0"

package = "exasol-driver-lua"
version = tag .. "-1"

source = {
    url = 'git://github.com/exasol/exasol-driver-lua',
    tag = tag
}

description = {
    summary = "Exasol SQL driver for Lua",
    labels = {"luasql", "sql", "database", "driver", "exasol"},
    detailed = [[Exasol SQL driver for Lua based on the LuaSQL API.

    You can find the user guide in the project's GitHub repository.
    
    Links:
    
    - User guide: https://github.com/exasol/exasol-driver-lua/blob/master/doc/user_guide/user_guide.md]],
    homepage = "https://github.com/exasol/exasol-driver-lua",
    issues_url = "https://github.com/exasol/exasol-driver-lua/issues",
    license = "MIT",
    maintainer = 'Exasol <opensource@exasol.com>'
}

dependencies = {
    "lua == 5.4",
    "luasocket >= 3.0rc1-2",
    "luasec >= 1.0.2-1",
    "luaossl >= 20200709-0",
    "lua-cjson == 2.1.0", -- pinned to prevent "undefined symbol: lua_objlen" in 2.1.0.6 (https://github.com/mpx/lua-cjson/issues/56)
    "base64 >= 1.5-3",
    "exaerror >= 1.2.2-1",
    "remotelog >= 1.1.1-1"
}

test_dependencies = {
    "busted >= 2.0.0-1",
    "mockagne >= 1.0-2",
    "luacov >= 0.15.0-1",
    "luacov-coveralls >= 0.2.3-1",
    "luacheck >= 0.25.0-1"
}

test = {
    type = "busted"
}

build = {
    type = "builtin",
    modules = {
        luasqlexasol = "src/luasqlexasol.lua",
        connection_properties = "src/connection_properties.lua",
        connection = "src/connection.lua",
        constants = "src/constants.lua",
        cursor_data = "src/cursor_data.lua",
        cursor = "src/cursor.lua",
        environment = "src/environment.lua",
        exasol_websocket = "src/exasol_websocket.lua",
        luws = "src/luws.lua",
        util = "src/util.lua",
        websocket_datahandler = "src/websocket_datahandler.lua",
        websocket = "src/websocket.lua",
    },
    copy_directories = { "doc" }
}
