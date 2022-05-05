-- Configuration for LDoc
-- See https://stevedonovan.github.io/ldoc/manual/doc.md.html

project = "Lua driver for Exasol"
description = [[# A LuaSQL driver for the Exasol database

Check out the [user guide](https://github.com/exasol/exasol-driver-lua/blob/main/doc/user_guide/user_guide.md) for more details.

## Features

1. Connect to an [Exasol](https://www.exasol.com/) database and execute SQL statements
1. Encrypted communication via TLS
1. Compatible with the [LuaSQL](https://keplerproject.github.io/luasql/) API

## Information for Users

* [GitHub project](https://github.com/exasol/exasol-driver-lua)
* [User Guide](https://github.com/exasol/exasol-driver-lua/blob/main/doc/user_guide/user_guide.md)
* [Example Usage](examples/examples.lua.html)
* [Change Log](https://github.com/exasol/exasol-driver-lua/blob/main/doc/changes/changelog.md)
* [MIT License](https://github.com/exasol/exasol-driver-lua/blob/main/LICENSE)

### Dependencies

See the [dependencies list](https://github.com/exasol/exasol-driver-lua/blob/main/dependencies.md) for build and test dependencies and license information.

## Information for Developers

Requirement, design documents and coverage tags are written in [OpenFastTrace](https://github.com/itsallcode/openfasttrace) format.

* [Developers Guide](https://github.com/exasol/exasol-driver-lua/blob/main/doc/developer_guide/developer_guide.md)
* [System Requirements](https://github.com/exasol/exasol-driver-lua/blob/main/doc/system_requirements.md)
* [Design](https://github.com/exasol/exasol-driver-lua/blob/main/doc/design.md)
]]
title = "Reference"
file = {"./src/", exclude={"./src/luasql/exasol/luws.lua"}}
examples = {"./doc/user_guide/examples.lua"}
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
