<!-- @formatter:off -->
# Dependencies

The Lua Exasol database driver requires on [Lua 5.4][lua] or higher to run. This is available in Exasol 7.1.x. and above.

The following dependencies are preinstalled on Exasol and are not part of the installation bundle:

* `luasocket`
* `lua-cjson`
* `luaossl`
* `luasec`

## Compile Dependencies

| Dependency                                                          | License                                                                 |
|---------------------------------------------------------------------|-------------------------------------------------------------------------|
| [base64](https://github.com/iskolbin/lbase64)                       | [MIT][mit]                                                              |
| [exaerror](https://github.com/exasol/error-reporting-lua)           | [MIT](https://github.com/exasol/error-reporting-lua/blob/main/LICENSE)  |
| [Lua 5.4][lua]                                                      | [MIT][mit]                                                              |
| [lua-cjson](https://github.com/openresty/lua-cjson)                 | [MIT](https://github.com/openresty/lua-cjson/blob/master/LICENSE)       |
| [luaossl](http://25thandclement.com/~william/projects/luaossl.html)  | [MIT](http://25thandclement.com/~william/projects/luaossl.html#license) |
| [luasec](https://github.com/brunoos/luasec)                         | [MIT](https://github.com/brunoos/luasec/blob/master/LICENSE)            |
| [luasocket](https://lunarmodules.github.io/luasocket/)              | [MIT][mit]                                                              |
| [remotelog](https://github.com/exasol/remotelog-lua)                | [MIT](https://github.com/exasol/remotelog-lua/blob/main/LICENSE)        |

## Test Dependencies

| Dependency                                                                   | License                                                                     |
|------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| [busted](https://lunarmodules.github.io/busted/)                             | [BSD License 3](https://github.com/Olivine-Labs/busted/blob/master/LICENSE) |
| [mockagne](https://github.com/mockagne/mockagne)                             | [MIT](https://github.com/mockagne/mockagne/blob/master/LICENSE)             |
| [LuaCheck][luacheck]                                                         | [MIT][mit]                                                                  |
| [LuaCov][luacov]                                                             | [MIT][mit]                                                                  |
| [LuaCov-Coveralls](https://github.com/mockagne/mockagne/blob/master/LICENSE) | [MIT](https://github.com/moteus/luacov-coveralls/blob/master/LICENSE)       |
| [Shellcheck][shellcheck]                                                     | [GPL V3][gpl3]                                                              |
| [SQLite 3](https://www.sqlite.org/index.html) | [Public Domain](https://www.sqlite.org/copyright.html) |
## Build Dependencies

| Dependency                                                       | License                                                           |
|------------------------------------------------------------------|-------------------------------------------------------------------|
| [amalg](https://github.com/siffiejoe/lua-amalg/)                 | [MIT][mit]                                                        |
| [LDoc](https://stevedonovan.github.io/ldoc/manual/doc.md.html)   | [MIT](https://github.com/lunarmodules/LDoc/blob/master/COPYRIGHT) |
| [LuaRocks][luarocks]                                             | [MIT][mit]                                                        |
| [LuaSQL-SQLite3](https://github.com/LuaDist/luasql-sqlite3)      | [MIT][mit]                                                        |

[lua]: https://www.lua.org/
[luacheck]: https://github.com/mpeterv/luacheck
[luacov]: https://github.com/lunarmodules/luacov
[luarocks]: https://luarocks.org/
[luaunit]: https://github.com/bluebird75/luaunit
[shellcheck]: https://www.shellcheck.net/

[gpl3]: https://opensource.org/license/gpl-3-0
[mit]: https://opensource.org/licenses/MIT
[bsd]: http://opensource.org/licenses/BSD-3-Clause
