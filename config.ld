-- Configuration for LDoc
-- See https://stevedonovan.github.io/ldoc/manual/doc.md.html

project = "Lua driver for Exasol"
description = [[# A LuaSQL driver for the Exasol database

* [Example usage](./examples/examples.lua.html)

## More Information

* [GitHub project](https://github.com/exasol/exasol-driver-lua)
* [User Guide](topics/user_guide.md.html)
* [Changelog](https://github.com/exasol/exasol-driver-lua/blob/main/doc/changes/changelog.md)
* [Developer Guide](topics/developer_guide.md.html)
* [Exasol database](https://www.exasol.com/)

## LuaSQL

* [LuaSQL project](https://keplerproject.github.io/luasql/)
* [LuaSQL manual](https://keplerproject.github.io/luasql/manual.html)
]]
title = "Reference"
file = {"./src/", exclude={"./src/luws.lua"}}
examples = {"./doc/user_guide/examples.lua"}
--readme = "./README.md"
readme = {"./doc/user_guide/user_guide.md", "./doc/developer_guide/developer_guide.md"}
package = "."
format = "markdown"
output = "index"
dir = "./target/ldoc"
colon = false
boilerplate = false -- ignore first comment
ext = "html"
one = false -- one column style
pretty = "lua" -- code prettifier
prettify_files = true
charset = "UTF-8"
sort = false
backtick_references = false
wrap = true
no_space_before_args = true
all = true -- show also local functions
