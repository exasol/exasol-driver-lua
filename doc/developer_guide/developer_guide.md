# exasol-driver-lua &mdash; Developers Guide

This document contains developer information on how to build, run, modify and publish this Lua project.

## Prerequisites

This project has the following prerequisites:

* [Lua](https://www.lua.org/) &ge; 5.4
* [Luarocks](https://luarocks.org/) &ge; 3.8: Package manager for Lua
* [OpenSSL](https://www.openssl.org/) &ge; 1.1: Library used for TLS connections and RSA encryption

Install the prerequisites like this:

* macOS:
    ```sh
    brew install lua luarocks openssl@1.1
    ```
* Fedora: Installing `luaossl` via luarocks fails on Fedora 35 with a compile error. That's why we install `lua-luaossl` via `yum`:
    ```sh
    sudo yum install lua lua-devel luarocks openssl-devel lua-luaossl
    ```

### Install Runtime and Test Dependencies

See the [list of dependencies](../../dependencies.md) for details. Install dependencies by executing:

```sh
luarocks install --local --deps-only *.rockspec
```

On macOS you may need to specify the path to OpenSSL:

```sh
openssl=/usr/local/Cellar/openssl@1.1/1.1.1m/
luarocks install --local --deps-only *.rockspec OPENSSL_DIR=$openssl CRYPTO_DIR=$openssl
```

## Running Tests

You need an Exasol database for running the tests. You can start a Docker instance either manually as described in [docker-db](https://github.com/EXASOL/docker-db) or using the [integration-test-docker-environment](https://github.com/exasol/integration-test-docker-environment).

Once Exasol is running, start the tests by executing:

```sh
EXASOL_HOST=<host> \
  EXASOL_PORT=<port> \
  EXASOL_USER=<user> \
  EXASOL_PASSWORD=<password> \
  ./tools/runtests.sh
```

The following environment variables have a default value and can be omitted:

* `EXASOL_PORT` = `8563`
* `EXASOL_USER` = `sys`
* `EXASOL_PASSWORD` = `exasol`

You can enable tracing by setting environment variable `LOG_LEVEL=TRACE`.

To run a single test:

```sh
export LUA_PATH="./src/?.lua;./test/?.lua;$(luarocks path --lr-path)"
export EXASOL_HOST=<host>
lua test/itest_connection.lua
```
