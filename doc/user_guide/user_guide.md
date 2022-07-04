# exasol-driver-lua – User Guide

The Exasol Driver for Lua allows you to execute queries on an Exasol database and retrieve the results. This user-guide shows how to use the driver.

## Installing the Driver and Dependencies

### Install Runtime Dependencies

This project has the following prerequisites:

* [Lua](https://www.lua.org/) ≥ 5.4
* [Luarocks](https://luarocks.org/) ≥ 3.8: Package manager for Lua
* [OpenSSL](https://www.openssl.org/) ≥ 1.1: Library used for TLS connections and RSA encryption

Install the prerequisites like this:

* macOS:
    ```sh
    brew install lua luarocks openssl@1.1
    ```
* Fedora: Installing `luaossl` via luarocks fails on Fedora 35 with a compile error. That's why we install `lua-luaossl` via `yum`:
    ```sh
    sudo yum install lua lua-devel luarocks openssl-devel lua-luaossl
    ```

### Install `exasol-driver-lua`

We recommend installing Lua dependencies to your local luarocks directory, usually `$HOME/.luarocks`. To setup the Lua search path, run this command in every shell or add it to an init script:

```sh
eval $(luarocks path)
```

Then install `exasol-driver-lua` and required [Lua libraries](../../dependencies.md) by running

```sh
luarocks install --local luasql-exasol
```

On macOS you may need to specify the path to OpenSSL:

```sh
openssl=/usr/local/Cellar/openssl@1.1/1.1.1m/
luarocks install --local luasql-exasol OPENSSL_DIR=$openssl CRYPTO_DIR=$openssl
```

## Executable Example

This repository contains [examples.lua](./examples.lua) as an example of how to use `exasol-driver-lua`.

After installing `exasol-driver-lua`, you can run the example script like this:

```sh
EXASOL_HOST=<host> \
  EXASOL_PORT=8563 \
  EXASOL_USER=<DB-user> \
  EXASOL_PASSSWORD=<DB-Password> \
  lua doc/user_guide/examples.lua
```

You will need to adjust host, port and credentials. If everything is setup correctly, the script will log the following:

```
2022-04-27 18:07:09 (038.649ms) [INFO]   Successfully connected to Exasol database at 192.168.56.7:8563 with user sys
2022-04-27 18:07:09 (067.318ms) [INFO]   Successfully executed query
2022-04-27 18:07:09 (067.354ms) [INFO]   Dice roll result: 6
2022-04-27 18:07:09 (067.362ms) [INFO]   Cursor closed successfully
2022-04-27 18:07:09 (067.368ms) [INFO]   Reading EXA_METADATA
2022-04-27 18:07:09 (078.316ms) [INFO]     - row 1: maxBinaryLiteralLength = '0'
2022-04-27 18:07:09 (078.344ms) [INFO]     - row 2: maxCatalogNameLength = '128'
2022-04-27 18:07:09 (078.352ms) [INFO]     - row 3: maxCharLiteralLength = '2000000'
2022-04-27 18:07:09 (078.359ms) [INFO]     - row 4: maxColumnNameLength = '128'
2022-04-27 18:07:09 (078.374ms) [INFO]     - row 5: maxColumnsInGroupBy = '0'
2022-04-27 18:07:09 (078.499ms) [INFO]   Connection closed successfully
2022-04-27 18:07:09 (078.513ms) [INFO]   Environment closed successfully
```

## Usage

`exasol-driver-lua` follows the API of [LuaSQL](https://keplerproject.github.io/luasql/), so the [LuaSQL manual](https://keplerproject.github.io/luasql/manual.html) is a good starting point.

The following describes the basic usage. See the [API documentation](https://exasol.github.io/exasol-driver-lua/api/) for a detailed description of each method.

### Configure Logging

The driver uses [remotelog](https://github.com/exasol/remotelog-lua#readme) for logging, so you can configure the log level like this:

```lua
local log = require("remotelog")
log.set_level("INFO")
```

See remotelog's [user guide](https://github.com/exasol/remotelog-lua/blob/main/doc/user_guide/user_guide.md) for details.

### Creating an Environment

The environment allows you to create database connections:

```lua
-- Import the library
local driver = require("luasql.exasol")
-- Create a new environment
local environment = driver.exasol()

-- Use the environment to create database connections...
```

### Creating a Connection

You can create a database connection using the environment:

```lua
-- Create a new connection with default properties
local connection, err = environment:connect("<hostname>:8563", "<username>", "<password>")

-- Create a new connection with custom properties
local properties = {tls_verify = "none", tls_protocol = "tlsv1_2", tls_options = "no_tlsv1"}
local connection, err = environment:connect("<hostname>:8563", "<username>", "<password>", properties)

if err ~= nil then
  -- Handle connection error
end
```

The `connect()` method expects four arguments:

1. The source name consists of hostname or IP address of the database and the port.
2. The name of the database user.
3. The password of the database user.
4. An optional table with connection properties, see below for details.

The `connect()` returns two results:

1. The connection object if the connection was established successfully or `nil` in case of an error
2. An error in case the operation failed.

#### Connection Properties

When creating a new connection you can specify the following properties:

* `tls_verify` specifies how the database's TLS certificate should be verified. Possible values are:
  * `none` (default)
  * `peer`
  * `client_once`
  * `fail_if_no_peer_cert`
* `tls_protocol` specifies the TLS protocol for connecting to the database. Possible values are:
  * `tlsv1`
  * `tlsv1_1`
  * `tlsv1_2` (default)
  * `tlsv1_3`
* `tls_options` specifies additional options for OpenSSL, e.g. `no_tlsv1`. The default value is `all`. You can get a complete list of supported options by executing the following Lua code:
    ```lua
    require("ssl").config.options
    ```

### Executing SQL Statements and Queries

You can execute SQL statements and queries using a connection:

```lua
local cursor, err = connection:execute("<statement>")
if err ~= nil then
  -- Handle query error
end
```

The `execute()` method returns two results:

1. A cursor object if there are results (e.g. for a `SELECT` query), or the number of rows affected by the command (e.g. for an `UPDATE` statement).
2. An error in case the operation failed.

### Reading the Query Result From a Cursor

The `fetch()` method returns the next row. If there are no more rows it returns `nil` and closes the cursor.

`fetch()` supports two modes for the result format:

* Numeric indices (default, option `"n"`): the row table is a list with numeric indices.
* Alphanumeric indices (option `"a"`): the row table is a map using column names as indices.

#### Reading a Single Row

This reads the first row using numeric indices.

```lua
-- Execute an SQL query to get a cursor
local cursor = ...

-- Get the first row:
local first_row = cursor:fetch()
-- Get column values from the first row (index starts with 1):
let first_col = first_row[1]
let second_col = first_row[2]

-- Close cursor
if not cursor:close() then
    -- Handle error
end
```

#### Iterating Over All Rows

This reads all rows using alphanumeric indices.

```lua
-- Define reusable table for storing row data
local row = {}

-- Fetch first row
row = cursor:fetch(row, "a")

-- Iterate over rows
while row ~= nil do
    -- Process row...
    local col1 = row["COLUMN_1"]
    -- Fetch next row
    row = cursor:fetch(row, "a")
end
```

To reduce memory usage you can optionally pass a table as first argument to `fetch()`. This avoids creating new tables for each row.

When there are no more rows, `fetch()` returns `nil` and automatically closes the cursor.

### Closing a Connection

```lua
connection:close()
```

Close the connection after you have closed all cursors created with it. The `close()` method will return `false` if not all cursors where closed or if the connection is already closed.

### Closing an Environment

```lua
environment:close()
```

Close the environment after you have closed all connections created with it. The `close()` method will return `false` if not all connections where closed or if the environment is already closed.

## Using `exasol-driver-lua` in an Exasol UDF

Exasol version 7.1 or later allows running Lua code in [user defined functions (UDF)](https://docs.exasol.com/db/latest/database_concepts/udf_scripts.htm). The exasol-driver-lua uses only dependencies that are available to UDFs or that can be included into an package using amalgamation. This makes it possible to also use it in an Exasol UDF, e.g. for accessing another Exasol database. Some required C-Lua-interface packages are shipped with Exasol 8 and later. So Exasol 8 is required to run the driver.

To build such a package follow these steps:

1. Install exasol-driver-lua as described [here](#installing-the-driver-and-dependencies).
2. Install [amalg](https://github.com/siffiejoe/lua-amalg/):
    ```sh
    luarocks --local install amalg
    ```
3. Create a Lua script `udf.lua` for your UDF that uses the exasol driver, e.g.
    ```lua
    local driver = require("luasql.exasol")
    function run(ctx)
        return "Loaded driver: "..tostring(driver)
    end
    ```
4. Run the following command to build the package:
    ```sh
    amalg.lua --fallback --script=udf.lua --output udf-amalg.lua \
      luasql.exasol luasql.exasol.CursorData luasql.exasol.Environment \
      luasql.exasol.Websocket luasql.exasol.WebsocketDatahandler \
      luasql.exasol.Cursor luasql.exasol.util \
      luasql.exasol.constants luasql.exasol.Connection \
      luasql.exasol.ExasolWebsocket luasql.exasol.ConnectionProperties \
      luasql.exasol.luws luasql.exasol.base64 \
      remotelog exaerror message_expander
    ```
    This command bundles all required modules of the driver as well as the third party modules `remotelog exaerror message_expander` to a single Lua file, using `udf.lua` as entry point.

    **Note:** Do not add argument `--debug` because this will generate code that won't run in a UDF.
5. Run the following statement in your Exasol database to create the UDF:
    ```sql
    --/
    CREATE OR REPLACE LUA SCALAR SCRIPT UDF_SCHEMA.RUN_UDF_TEST(argument VARCHAR(2000)) RETURNS VARCHAR(2000) AS
        -- Insert content of udf-amalg.lua here
    /;
    ```
6. Execute the UDF by running this statement:
    ```sql
    SELECT UDF_SCHEMA.RUN_UDF_TEST('argument')
    ```

See files [amalg_util.lua](../../spec/amalg_util.lua) and [udf_spec.lua](../../spec/integration/udf_spec.lua) as an example how to automate this process.
