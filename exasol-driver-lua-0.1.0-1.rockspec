package = "exasol-driver-lua"
version = "0.1.0-1"

source = {
    url = 'git://github.com/exasol/exasol-driver-lua',
    tag = "0.1.0"
}

description = {
    summary = "",
    detailed = [[...

    You can find the user guide in the projects GitHub repository.
    
    Links:
    
    - User guide: https://github.com/exasol/exasol-driver-lua/blob/master/doc/user_guide/user_guide.md]],
    homepage = "https://github.com/exasol/exasol-driver-lua",
    license = "MIT",
    maintainer = 'Exasol <opensource@exasol.com>'
}

dependencies = {"lua >= 5.4, <= 5.4"}

-- With support for LuaRocks 3 we will enable the following configuration option. Right now LuaRocks 2 is still the
-- current version on Ubuntu, so it is too early for this.
--
-- rockspec_format = "3.0"
-- build_dependencies = {"luaunit >= 3.3-1"}

build = {
    type = "builtin",
    modules = {
        luasqlexasol = "src/luasqlexasol.lua"
    },
    copy_directories = { "doc", "test" }
}