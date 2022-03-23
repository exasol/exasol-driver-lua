# exasol-driver-lua &mdash; Developers Guide

This document contains developer information on how to build, run, modify and publish this Lua project.

## Prerequisites

This project has the following prerequisites:

* [Lua](https://www.lua.org/) &ge; 5.4
* [Luarocks](https://luarocks.org/) &ge; 3.8: Package manager for Lua
* [OpenSSL](https://www.openssl.org/) &ge; 1.1: Library used for TLS connections and RSA encryption
* [PlantUML](https://plantuml.com/): Tool for generating images from UML diagrams

Install the prerequisites like this:

* macOS:
    ```sh
    brew install lua luarocks openssl@1.1 plantuml
    ```
* Fedora: Installing `luaossl` via luarocks fails on Fedora 35 with a compile error. That's why we install `lua-luaossl` via `yum`:
    ```sh
    sudo yum install lua lua-devel luarocks openssl-devel lua-luaossl plantuml
    ```

### Install Runtime Dependencies

See the [list of dependencies](../../dependencies.md) for details. Install dependencies by executing:

```sh
luarocks install --local --deps-only *.rockspec
```

On macOS you may need to specify the path to OpenSSL:

```sh
openssl=/usr/local/Cellar/openssl@1.1/1.1.1m/
luarocks install --local --deps-only *.rockspec OPENSSL_DIR=$openssl CRYPTO_DIR=$openssl
```

### Install Test and Build Dependencies

```sh
luarocks install --local busted
```

#### Troubleshooting `lua-cjson` installation

`lua-cjson` is pinned to version `2.1.0` because later versions fail installation with error `undefined symbol: lua_objlen` or `implicit declaration of function 'lua_objlen' is invalid in C99`:

```
lua_cjson.c:743:19: error: implicit declaration of function 'lua_objlen' is invalid in C99 [-Werror,-Wimplicit-function-declaration]
            len = lua_objlen(l, -1);
```

To use the latest version you can optionally install it with additional build flags:

```sh
luarocks install lua-cjson --local "CFLAGS=-O3 -Wall -pedantic -DNDEBUG -DLUA_COMPAT_5_3"
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

This will run all tests and print the test coverage.

The following environment variables have a default value and can be omitted:

* `EXASOL_PORT` = `8563`
* `EXASOL_USER` = `sys`
* `EXASOL_PASSWORD` = `exasol`

You can enable tracing by setting environment variable `LOG_LEVEL=TRACE`.

To run a single test:

```sh
export EXASOL_HOST=<host>
busted spec/integration/connection_spec.lua
# or
lua spec/integration/connection_spec.lua
```

## Source Formatter

Use the following plugins in your IDE:

* Visual Studio Code: [vscode-lua-format](https://marketplace.visualstudio.com/items?itemName=Koihik.vscode-lua-format)

### Command Line Usage

First install prerequisites:

* macOS:
    ```sh
    brew install cmake
    ```

Then install [LuaFormatter](https://github.com/Koihik/LuaFormatter):

```sh
luarocks install --local --server=https://luarocks.org/dev luaformatter
```

Run the formatter like this:

```sh
./tools/format-lua.sh
```

**This will overwrite sources directly**

## Generate UML Images From UML Diagrams

To generate images from the UML diagrams in [/doc/model/diagrams](../model/diagrams/), run

```sh
./tools/build-diagrams.sh
```

## Run Requirements Tracing

To run the requirements tracing with [OpenFastTrace](https://github.com/itsallcode/openfasttrace), run

```sh
./tools/trace-requirements.sh
```
