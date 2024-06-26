# Exasol Driver for Lua

A LuaSQL driver for the Exasol database.

[![Build and test Lua project](https://github.com/exasol/exasol-driver-lua/actions/workflows/ci-build.yml/badge.svg)](https://github.com/exasol/exasol-driver-lua/actions/workflows/ci-build.yml)

Check out the [user guide](doc/user_guide/user_guide.md) for more details.

## Features

1. Connect to an [Exasol](https://www.exasol.com/) database and execute SQL statements
2. Encrypted communication via TLS
3. Compatible with the [LuaSQL](https://github.com/lunarmodules/luasql) API
4. Runs inside an Exasol [user defined functions (UDF)](https://docs.exasol.com/db/latest/database_concepts/udf_scripts.htm), see the [user guide](./doc/user_guide/user_guide.md#using-exasol-driver-lua-in-an-exasol-udf) for details. Exasol 8 or later is required for this.

## Information for Users

* [User Guide](doc/user_guide/user_guide.md)
* [Example Usage](doc/user_guide/examples.lua)
* [API Documentation](https://exasol.github.io/exasol-driver-lua/api/)
* [Change Log](doc/changes/changelog.md)
* [MIT License](LICENSE)

### Dependencies

See the [dependencies list](dependencies.md) for build and test dependencies and license information.

## Information for Developers

Requirement, design documents and coverage tags are written in [OpenFastTrace](https://github.com/itsallcode/openfasttrace) format.

* [Developer Guide](doc/developer_guide/developer_guide.md)
* [System Requirements](doc/system_requirements.md)
* [Design](doc/design.md)
