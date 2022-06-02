---@diagnostic disable: undefined-global
-- luacheck: globals describe it before_each after_each
require("busted.runner")()
local exasol_driver = require("luasql.exasol")
local sqlite3_driver = require("luasql.sqlite3")
local log = require("remotelog")
local config = require("config")
config.configure_logging()

local function create_exasol_driver()
    local connection_params = config.get_connection_params()
    local function teardown()
        -- nothing to do
    end
    return {
        name = "exasol",
        create_env = exasol_driver.exasol,
        valid_connect_args = {connection_params.source_name, connection_params.user, connection_params.password},
        invalid_connect_args = {"invalidhost", "invalid user", "invalid password"},
        teardown = teardown
    }
end

local function create_sqlite3_driver()
    local db_file = os.tmpname()
    log.debug("Deleting temp file %s for sqlite3", db_file)
    local function teardown()
        log.debug("Deleting temp sqlite3 db %s", db_file)
        assert(os.remove(db_file))
    end
    return {
        name = "sqlite3",
        create_env = sqlite3_driver.sqlite3,
        valid_connect_args = {db_file},
        invalid_connect_args = {"/tmp/missing-dir/sqlite.db"},
        teardown = teardown
    }
end

local function assert_methods_exists(object, expected_methods)
    for _, method_name in ipairs(expected_methods) do
        local method = object[method_name]
        assert.is_not_nil(method, "Field " .. method_name .. " does not exist")
        assert.is_same(type(method), "function", "Field " .. method_name .. " must be a method")
    end
end

describe("LuaSQL compatibility", function()
    for _, driver in ipairs({create_exasol_driver(), create_sqlite3_driver()}) do
        describe("with driver " .. driver.name, function()
            setup(function()
                -- driver.setup()
            end)
            teardown(function()
                driver.teardown()
            end)

            it("creating and closing environment", function()
                local env = driver.create_env()
                assert.not_nil(env)
                assert.is_true(env:close())
            end)

            it("creating and closing connection", function()
                local env = driver.create_env()
                local conn = assert(env:connect(table.unpack(driver.valid_connect_args)))
                assert.not_nil(conn)
                assert.is_true(conn:close())
                assert.is_true(env:close())
            end)

            describe("Connection", function()
                local env = nil
                local conn = nil

                before_each(function()
                    env = driver.create_env()
                    conn = assert(env:connect(table.unpack(driver.valid_connect_args)))
                end)

                after_each(function()
                    assert.is_true(conn:close())
                    assert.is_true(env:close())
                end)

                it("has expected methods", function()
                    assert_methods_exists(conn, {"close", "commit", "execute", "rollback", "setautocommit"})
                end)

                describe("Cursor", function()
                    local cur = nil

                    before_each(function()
                        cur = assert(conn:execute([[select 1 as 'ID', 'foobar' as "NAME"]]))
                    end)

                    after_each(function()
                        assert.is_true(cur:close())
                    end)

                    it("has expected methods", function()
                        assert_methods_exists(cur, {"close", "fetch", "getcolnames", "getcoltypes"})
                    end)

                    it("fetches results in index mode", function()
                        -- sqlite3 driver does not conform to API, fetch() always returns the number of results.
                        local row = {}
                        cur:fetch(row, "n")
                        assert.is_same({1, "foobar"}, row)
                    end)

                    it("fetches results in alphanumeric mode", function()
                        -- sqlite3 driver does not conform to API, fetch() always returns the number of results.
                        local row = {}
                        cur:fetch(row, "a")
                        assert.is_same({ID = 1, NAME = "foobar"}, row)
                    end)

                    it("gets column names", function()
                        assert.is_same({"ID", "NAME"}, cur:getcolnames())
                    end)

                    it("gets column types", function()
                        local expected_column_types = {"DECIMAL", "CHAR"}
                        if driver.name == "sqlite3" then
                            expected_column_types = {}
                        end
                        assert.is_same(expected_column_types, cur:getcoltypes())
                    end)
                end)
            end)
        end)
    end
end)
