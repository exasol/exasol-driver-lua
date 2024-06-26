# Introduction

## Acknowledgments

This document's section structure is derived from the "[arc42](https://arc42.org/)" architectural template by Dr. Gernot Starke, Dr. Peter Hruschka.

# Constraints

This section introduces technical system constraints.

## Restrict Libraries to the Ones Available to Exasol UDFs

`dsn~use-available-exasol-udf-libraries-only~1`

EDL uses the following external Lua modules that are available to Exasol UDFs:
* `luasocket`
* `luasec`
* `luaossl`
* `lua-cjson`

EDL uses the following external Lua modules that can be amalgamated into a single package:
* exaerror
* remotelog

EDL does not use other external modules not listed here.

Rationale:

This will allow EDL to run inside an Exasol UDF.

Covers:

* [const~use-available-exasol-udf-libraries-only~1](./system_requirements.md#restrict-libraries-to-the-ones-available-to-exasol-udfs)

Needs: itest

# Solution Strategy

EDL uses Exasol's public [websocket-api](https://github.com/exasol/websocket-api) because it's a stable interface, well documented and does not require native libraries.

## Requirement Overview

Please refer to the [System Requirement Specification](system_requirements.md) for user-level requirements.

# Building Blocks

![Class Diagram](./images/generated/cl_exasol_driver_lua.svg)

See [Diagram source](./model/diagrams/class/cl_exasol_driver_lua.plantuml).

# Runtime

Note: the following sequence diagrams only show a simplified workflow without the `Websocket` class and `luws`. See section [Websocket Request/Response](#websocket-requestresponse) for a detailed description of the request/response cycle.

## Environment

### Connecting to the Database
`dsn~env-connect~1`

![Sequence Diagram: Connecting to the database](./images/generated/seq_environment_connect.svg)

See [Diagram source](./model/diagrams/sequence/seq_environment_connect.plantuml).

### Closing the Environment
`dsn~env-close~1`

![Sequence Diagram: Closing the Environment](./images/generated/seq_environment_close.svg)

See [Diagram source](./model/diagrams/sequence/seq_environment_close.plantuml).

## Connection

### Executing a Statement

![Sequence Diagram: Executing Statements and fetching results](./images/generated/seq_connection_execute.svg)

See [Diagram source](./model/diagrams/sequence/seq_connection_execute.plantuml).

### Setting Autocommit for the Connection

![Sequence Diagram: Setting Autocommit](./images/generated/seq_connection_setautocommit.svg)

See [Diagram source](./model/diagrams/sequence/seq_connection_setautocommit.plantuml).

### Committing a Transaction for the Connection

![Sequence Diagram: Committing a Transaction](./images/generated/seq_connection_commit.svg)

See [Diagram source](./model/diagrams/sequence/seq_connection_commit.plantuml).

### Rolling Back a Transaction for the Connection

![Sequence Diagram: Rolling Back a Transaction](./images/generated/seq_connection_rollback.svg)

See [Diagram source](./model/diagrams/sequence/seq_connection_rollback.plantuml).


### Closing the Connection

![Sequence Diagram: Closing the Connection](./images/generated/seq_connection_close.svg)

See [Diagram source](./model/diagrams/sequence/seq_connection_close.plantuml).

## Cursor

### Fetching Results

![Sequence Diagram: Closing a Cursor](./images/generated/seq_cursor_fetch.svg)

See [Diagram source](./model/diagrams/sequence/seq_cursor_fetch.plantuml).

### Getting Column Names

![Sequence Diagram: Closing a Cursor](./images/generated/seq_cursor_getcolnames.svg)

See [Diagram source](./model/diagrams/sequence/seq_cursor_getcolnames.plantuml).

### Getting Column Types

![Sequence Diagram: Closing a Cursor](./images/generated/seq_cursor_getcoltypes.svg)

See [Diagram source](./model/diagrams/sequence/seq_cursor_getcoltypes.plantuml).

### Closing a Cursor

![Sequence Diagram: Closing a Cursor](./images/generated/seq_cursor_close.svg)

See [Diagram source](./model/diagrams/sequence/seq_cursor_close.plantuml).

# Cross-cutting Concerns

## Websocket Request/Response

Detailed Websocket Request and Response cycle using `connection:execute()` as an example:

![Sequence Diagram: Websocket Request/Response](./images/generated/seq_websocket_request_response.svg)

See [Diagram source](./model/diagrams/sequence/seq_websocket_request_response.plantuml).

## Logging with remotelog
`dsn~logging-with-remotelog~1`

EDL uses [remotelog](https://github.com/exasol/remotelog-lua) for logging.

Rationale:

This library can log to the console and a remote receiver and is already used in other projects at Exasol.

Note:

EDL is a library that is used by other applications. That's why EDL does not configure log level or application name. This is the task of the application using EDL.

Covers:
* `req~console-logging~1`
* `req~remote-logging~1`

Needs: impl, utest

# Design Decisions

## Included Third-Party Lua Modules

We include the source code of some third party Lua modules in this repository. This section explains the rationale.

### [luws.lua](../src/luasql/exasol/luws.lua)

This module from [github.com/toggledbits/LuWS](https://github.com/toggledbits/LuWS) implements the WebSocket protocol. We include it's source code for the following reasons:

* The module is not published at [LuaRocks](https://luarocks.org/)
* The module requires modifications to work with Lua 5.4 and the original author requires backwards compatibility. See discussion at [LuWS issue #3](https://github.com/toggledbits/LuWS/issues/3).

### [base64.lua](../src/luasql/exasol/base64.lua)

This module from [github.com/iskolbin/lbase64](https://github.com/iskolbin/lbase64) implements a base64 encoder and decoder. We include it's source code for the following reasons:

* The module is not available in an Exasol UDF (see [list of auxiliary libraries](https://docs.exasol.com/db/latest/database_concepts/udf_scripts/lua.htm#AuxiliaryLibraries) for UDFs).
* The module uses the `load()` function for backwards compatibility with older Lua versions (see [the source code](https://github.com/iskolbin/lbase64/blob/master/base64.lua#L48-L50) for details). This `load()` function is not available in Exasol UDFs, so we had to modify the relevant code, breaking base64's backwards compatibility.

# Quality Scenarios

# Risks
