# exasol-driver-lua &mdash; Developers Guide

This document contains developer information on how to build, run, modify and publish this Lua project.

## Prerequisites

This project needs a Lua interpreter &ge; Lua 5.4 and Luarocks %ge; 3.8.

* macOS:
    ```sh
    brew install lua luarocks
    ```
* Fedora:
    ```sh
    sudo yum install lua lua-devel luarocks openssl-devel lua-luaossl
    ```

### Install Dependencies

Install dependencies by running

```sh
luarocks install --local --deps-only *.rockspec 
```

On macOS you may need to specify the path to OpenSSL:

```sh
openssl=/usr/local/Cellar/openssl@1.1/1.1.1m/
luarocks install --local --deps-only *.rockspec OPENSSL_DIR=$openssl CRYPTO_DIR=$openssl
```

## Running Tests

You need an Exasol database for running the tests. Start the tests by executing:

```sh
EXASOL_HOST=<host> \
  EXASOL_PORT=<port> \
  EXASOL_USER=<user> \
  EXASOL_PASSWORD=<password> \
  ./tools/runtests.sh
```

The following environment have a default value and can be omitted:

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