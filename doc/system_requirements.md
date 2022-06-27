<head><link href="oft_spec.css" rel="stylesheet"></head>

# System Requirement Specification &mdash; Exasol Driver for Lua

## Introduction

The Exasol driver for Lua (EDL) is a library for Lua that allows accessing an Exasol database to insert, update, delete and query data. EDL provides an API interface that closely resembles the API of [LuaSQL](https://keplerproject.github.io/luasql/) in order to act as a drop-in replacement.

## About This Document

### Target Audience

The target audience are software developers, requirement engineers, software designers. See section ["Stakeholders"](#stakeholders) for more details.

### Goal

The EDL main goal is to provide a ready-to-use library for accessing an Exasol database in Lua.

## Stakeholders

### Software Developers

Software Developers use this library for writing Lua applications that access an Exasol database.

## Terms and Abbreviations

The following list gives you an overview of terms and abbreviations commonly used in OFT documents.

* **EDL**: Exasol Driver for Lua
* **LuaSQL**: A database connectivity library for the Lua programming language
* **Client code**: A Lua program that uses EDL
* **UDF** / **User defined function**: Extension point in the Exasol database that allows users to write their own SQL functions, see the [documentation](https://docs.exasol.com/db/latest/database_concepts/udf_scripts.htm) for details
* **Virtual Schema**: Projection of an external data source that can be access like an Exasol database schema.
* **Virtual Schema adapter**: Plug-in for Exasol based on the Virtual Schema API that translates between Exasol and the data source.

## Features

Features are the highest level requirements in this document that describe the main functionality of EDL.

### LuaSQL API Interface
`feat~luasql-api~1`

EDL implements the [LuaSQL](https://keplerproject.github.io/luasql/) API as closely as possible.

Rationale:

LuaSQL is a mature library used in many projects. Lua developers are already familiar with its API. Implementing the LuaSQL API avoids reinventing the wheel and potential mistakes when designing a new API from scratch.

Extending the API with Exasol specific functions is however possible and already done for other databases.

Needs: req

### Run Inside an Exasol UDF
`feat~run-in-exasol-udf~1`

EDL runs inside an Exasol UDF.

Rationale:

The Virtual Schema Adapter for Exasol will be written in Lua and will need access to an Exasol database.

Needs: const

### Logging
`feat~logging~1`

EDL can log to the console or a remote log receiver. 

Rationale:

Console logging is useful for unit tests, remote logging for debugging a running Virtual Schema.

Needs: req

## Functional Requirements

### LuaSQL API

EDL implements the [LuaSQL API](https://keplerproject.github.io/luasql/manual.html). This contains the following components:

#### Entry Point
`req~luasql-entry-point~1`

Client code can load EDL using a `require` statement and create an [Environment](#environment) object:

```lua
local driver = require("luasql.exasol")
local env = driver.exasol()
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

#### Environment Objects

An Environment object provides the following methods:

##### Environment:connect()
`req~luasql-environment-connect~1`

```lua
environment:connect(sourcename[,username[,password]])
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

##### Environment:close()
`req~luasql-environment-close~1`

```lua
environment:close()
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

#### Connection Objects

A Connection object provides the following methods:

##### Connection:execute()
`req~luasql-connection-execute~1`

```lua
connection:execute(statement)
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

##### Connection:setautocommit()
`req~luasql-connection-setautocommit~1`

```lua
connection:setautocommit(boolean)
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

##### Connection:commit()
`req~luasql-connection-commit~1`
```lua
connection:commit()
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

##### Connection:rollback()
`req~luasql-connection-rollback~1`
```lua
connection:rollback()
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

##### Connection:close()
`req~luasql-connection-close~1`
```lua
connection:close()
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

#### Cursor Objects

A Cursor object provides the following methods:

#### Cursor:fetch()
`req~luasql-cursor-fetch~1`
```lua
cursor:fetch([table[,modestring]])
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

#### Cursor:fetch() with large result sets
`req~luasql-cursor-fetch-resultsethandle~1`
```lua
cursor:fetch([table[,modestring]])
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

#### Cursor:getcolnames()
`req~luasql-cursor-getcolnames~1`
```lua
cursor:getcolnames()
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

#### Cursor:getcoltypes()
`req~luasql-cursor-getcoltypes~1`
```lua
cursor:getcoltypes()
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

#### Cursor:close()
`req~luasql-cursor-close~1`
```lua
cursor:close()
```
Covers:
* `feat~luasql-api~1`
Needs: dsn

### LuaSQL Error Handling

### LuaSQL

## Non-functional Requirements

### Logging

UDFs which is one of the runtime environments for EDL run headless. That means that under normal circumstances the result of an UDF is the only way users can observe. For monitoring and debugging we therefore need logging.

#### Console Logging
`req~console-logging~1`

EDL can write log messages to the console.

Rationale:

This is useful for unit testing.

Covers:

* [feat~logging~1](#logging)

Needs: dsn

#### Remote Logging
`req~remote-logging~1`

EDL can write log messages to a remote log listener.

Rationale:

In an Exasol cluster, the console is not reachable for Lua UDFs, therefore the logger must send the log message to a remote receiver.

Covers:

* [feat~logging~1](#logging)

Needs: dsn
