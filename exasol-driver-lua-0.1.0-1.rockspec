rockspec_format = "3.0"
package = "exasol-driver-lua"
version = "0.1.0-1"

source = {
    url = 'git://github.com/exasol/exasol-driver-lua',
    tag = "0.1.0"
}

description = {
    summary = "Exasol SQL driver for Lua",
    labels = {"luasql", "sql", "database", "exasol"},
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
    "lua >= 5.3, <= 5.4",
    "luasocket >= 3.0rc1-2",
    "luasec >= 1.0.2-1",
    "luaossl >= 20200709-0",
    "lunajson >= 1.2.3-1",
    "base64 >= 1.5-3",
    "exaerror >= 1.2.2-1",
    "remotelog >= 1.1.1-1"
}

build_dependencies = {
    "luaunit >= 3.4-1",
    "luacov >= 0.15.0-1",
    "luacov-coveralls >= 0.2.3-1",
    "luacheck >= 0.25.0-1"
}

build = {
    type = "builtin",
    modules = {
        luasqlexasol = "src/luasqlexasol.lua"
    },
    copy_directories = { "doc", "test" }
}