# exasol-driver-lua 0.1.0, released 2022-06-13

Code name: Initial Release

## Summary

This is the initial release of the Lua driver for Exasol. It is fully compatible with the [LuaSQL](https://github.com/lunarmodules/luasql/) API and allows you to connect to an [Exasol](https://www.exasol.com/) database and execute SQL statements. You can find more information in the [readme](../../README.md) and the [user guide](../user_guide/user_guide.md).

## Features

* #1: Setup initial project
* #5: Added support for mode `"a"` for `cursor:fetch()`
* #24: Implemented `connection:setautocommit(true|false)`
* #45: Implemented `close()` methods as defined in the LuaSQL API
* #44: Implemented `cursor:getcoltypes()`
* #43: Implemented `cursor:getcolnames()`
* #7: Allow specifying TLS options for connecting to Exasol
* #41: Implemented `connection:commit()`
* #42: Implemented `connection:rollback()`
* #6: Added tests to verify LuaSQL compatibility

## Bugfixes

* #16: Fixed sporadic Websocket connection errors
* #51: Fixed wrong error message for invalid TLS parameter values
* #31: Upgraded integration tests to Exasol 7.1.10 to fix sporadic test failures

## Refactoring

* #25: Migrated tests to busted
* #18: Replaced lunajson with cjson
* #17: Added unit tests
* #35: Added integration test for fetching large results with fetch size smaller than the row size
* #33: Replaced `cjson.null` in returned row data with `luasql.exasol.NULL`
* #39: Renamed entry module to `luasql.exasol`
* #71: Removed unnecessary exceptions for luacheck
* #15: Added integration tests for all Exasol data types
* #9: Prepared publishing to luarocks
* #10: Added integration tests for timestamps with and without local timezone

## Documentation

* #17: Added requirements and design documents
* #34: Adapted documentation of error return type
* #12: Added user guide
