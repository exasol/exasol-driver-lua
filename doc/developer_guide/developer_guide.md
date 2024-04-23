# exasol-driver-lua &mdash; Developers Guide

This document contains developer information on how to build, run, modify and publish this Lua project.

## Prerequisites

This project has the following build dependencies:

* Install runtime dependencies as described in the [user guide](../user_guide/user_guide.md#install-runtime-dependencies).
* [PlantUML](https://plantuml.com/): Tool for generating images from UML diagrams.
* [LuaFormatter](https://github.com/Koihik/LuaFormatter): Tool for formatting the Lua source code. This requires `cmake` to install.

Install the build dependencies like this:

* macOS:
    ```sh
    brew install plantuml cmake
    ```
* Fedora:
    ```sh
    sudo yum install plantuml cmake
    ```
* Ubuntu:
    ```sh
    sudo apt install openssl libssl-dev sqllite3 libsqlite3-dev 
    ```

### Install Runtime Dependencies

See the [list of dependencies](../../dependencies.md) for details. Install dependencies by executing:

```sh
luarocks install --local --deps-only *.rockspec
```

On macOS you may need to specify the path to OpenSSL:

```sh
openssl=/usr/local/Cellar/openssl@1.1/1.1.1n/
luarocks install --local --deps-only *.rockspec OPENSSL_DIR=$openssl CRYPTO_DIR=$openssl
```

Adapt the path to `openssl` if you have installed a different version.

### Install Test and Build Dependencies

```sh
luarocks install --local busted
luarocks install --local ldoc
luarocks install --local --server=https://luarocks.org/dev luaformatter
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

To start Exasol in a Docker container, run the following:

```sh
docker run --publish 8563:8563 --detach --privileged --stop-timeout 120 exasol/docker-db:8.26.0
```

Once Exasol is running, start the tests by executing:

```sh
EXASOL_HOST=<host> \
  EXASOL_PORT=<port> \
  EXASOL_USER=<user> \
  EXASOL_PASSWORD=<password> \
  ./tools/runtests.sh
```

This will run all tests and print the test coverage.

The following environment variables have a default value and can be omitted when using the Docker container `exasol/docker-db`:

* `EXASOL_PORT` = `8563`
* `EXASOL_USER` = `sys`
* `EXASOL_PASSWORD` = `exasol`

You can enable tracing by setting environment variable `LOG_LEVEL=TRACE`.

To run a single test:

```sh
export EXASOL_HOST=<host>
luarocks test -- spec/integration/connection_spec.lua
# or
busted spec/integration/connection_spec.lua
# or
lua spec/integration/connection_spec.lua
```

## Source Formatter

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

# Troubleshooting

## `luarocks install` fails with `bad argument` error

```
Error: LuaRocks 3.9.0 bug (please report at https://github.com/luarocks/luarocks/issues).
Arch.: macosx-x86_64
/Users/chp/.luarocks/share/lua/5.4/socket/http.lua:38: bad argument #1 to 'receive' (string expected, got light userdata)
stack traceback:
        [C]: in function 'socket.http.request'
        .../Cellar/luarocks/3.9.0/share/lua/5.4/luarocks/fs/lua.lua:739: in upvalue 'request'
        .../Cellar/luarocks/3.9.0/share/lua/5.4/luarocks/fs/lua.lua:847: in upvalue 'http_request'
        .../Cellar/luarocks/3.9.0/share/lua/5.4/luarocks/fs/lua.lua:907: in function 'luarocks.fs.lua.download'
```

This is a [known issue](https://github.com/luarocks/luarocks/issues/1302). The recommended solution is to uninstall `luasec` with `luarocks remove --local luasec`.

If this does not help, backup and delete your complete `~/.luarocks`.
