# exasol-driver-lua &mdash; Developers Guide

This document contains developer information on how to build, run, modify and publish this Lua project.

## Prerequisites

This project needs a Lua interpreter &ge; Lua 5.4 and Luarocks %ge; 3.8.

* macOS:
    ```sh
    brew install lua luarocks
    ```

### Install Compile Dependencies

Install dependencies of by executing

```sh
luarocks install --deps-only *.rockspec
```

On macOS you may need to specify the path to OpenSSL:

```sh
openssl=/usr/local/Cellar/openssl@1.1/1.1.1m/
luarocks install --deps-only *.rockspec OPENSSL_DIR=$openssl CRYPTO_DIR=$openssl
```

## Install Test Dependencies

```sh
luarocks install luacov
luarocks install luaunit
luarocks install luacheck
```

## Running Tests

You need an Exasol database for running the tests. Start the tests by executing:

```sh
EXASOL_HOST=<host> \
  EXASOL_PORT=<port> \
  EXASOL_USER=<user> \
  EXASOL_PASSWORD=<password> \
  EXASOL_CERT_FINGERPRINT=<fingerprint> \
  ./tools/runtests.sh
```

The following environment have a default value and can be omitted:

* `EXASOL_PORT` = `8563`
* `EXASOL_USER` = `sys`
* `EXASOL_PASSWORD` = `exasol`

You can enable tracing by setting environment variable `LOG_LEVEL=TRACE`.

## Open Tasks

* Basics
    * Add requirements and design document
    * Add user documentation
    * Add Lua comments
    * Validate TLS certificate
    * Allow specifiying TLS certificate fingerprint
    * Setup CI build with Exasol 7.0 & 7.1
    * Add error reporting lua (https://github.com/exasol/error-reporting-lua/)
    * Build release with amalg.lua (https://github.com/exasol/row-level-security-lua/blob/main/tools/amalg.lua)
    * Install LuWS from rockspec (https://github.com/toggledbits/LuWS/issues/3)
    * Add a rockspec (https://github.com/exasol/error-reporting-lua/blob/main/exaerror-1.2.1-1.rockspec)
        * Publish to luarocks
    * Support result sets with more than 1,000 rows (https://github.com/exasol/websocket-api/blob/master/docs/commands/executeV1.md)
    * Specify additional properties (client name, driver name, ...) at login (https://github.com/exasol/websocket-api/blob/master/docs/commands/loginV3.md)
    * Allow specifying attributes when connecting to Exasol (https://github.com/exasol/websocket-api/blob/master/docs/WebsocketAPIV3.md#attributes-session-and-database-properties)
    * Ensure correct timezone handling for timestamps
* Advanced LuaSql compatible features
    * Use copas or busy waiting to avoid sleeping 1s until until response is available
    * Add support for compression
    * Allow specifying a list of hosts that is tried randomly
    * Add support for login with OpenID tokens (https://github.com/exasol/websocket-api/blob/master/docs/commands/loginTokenV3.md)
    * Support for connecting to cluster with `getHosts` (https://github.com/exasol/websocket-api/blob/master/docs/commands/getHostsV1.md)
    * Add support for `IMPORT INTO ... FROM LOCAL CSV FILE`
    * Add support for client side keepalive (https://github.com/exasol/websocket-api/blob/master/docs/WebsocketAPIV3.md#heartbeatfeedback-messages)
    * Add support for subconnections (https://github.com/exasol/websocket-api/blob/master/docs/WebsocketAPIV3.md#subconnections)
* Advanced features extending the LuaSql API:
    * Support prepared statements (https://github.com/exasol/websocket-api/blob/master/docs/commands/createPreparedStatementV1.md)
    * Add support for executeBatch (https://github.com/exasol/websocket-api/blob/master/docs/commands/executeBatchV1.md)
    * Abort queries (https://github.com/exasol/websocket-api/blob/master/docs/commands/abortQueryV1.md)
    * Add support for extensions provided by Postgres, MySQL, Oracle (https://keplerproject.github.io/luasql/manual.html#postgres_extensions)
