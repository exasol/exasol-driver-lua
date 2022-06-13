require("busted.runner")()
local driver = require("luasql.exasol")
local config = require("config")
local log = require("remotelog")

config.configure_logging()

describe("Exasol data types", function()
    local env = nil
    local connection = nil

    before_each(function()
        env = driver.exasol()
        local connection_params = config.get_connection_params()
        connection = assert(env:connect(connection_params.source_name, connection_params.user,
                                        connection_params.password))
    end)

    after_each(function()
        assert.is_true(connection:close())
        assert.is_true(env:close())
    end)

    local function cast(expression, type)
        return string.format("cast(%s as %s)", expression, type)
    end

    describe("converted to correct Lua type", function()
        -- See [list of all Exasol data types]
        -- (https://docs.exasol.com/db/latest/sql_references/data_types/datatypesoverview.htm)
        local test_cases = {
            --
            -- Boolean
            --
            {expression = "true", expected_value = true, expected_type = "BOOLEAN"},
            {expression = "false", expected_value = false, expected_type = "BOOLEAN"}, --
            --
            -- Numeric types
            --
            {expression = "42", expected_value = 42, expected_type = "DECIMAL"},
            {expression = "3.141", expected_value = "3.141", expected_type = "DECIMAL"},
            {expression = cast("100.123456", "DECIMAL(5,2)"), expected_value = "100.12", expected_type = "DECIMAL"},
            {expression = cast("3.141", "DOUBLE PRECISION"), expected_value = 3.141, expected_type = "DOUBLE"}, --
            --
            -- String types
            --
            {expression = "'abc'", expected_value = "abc", expected_type = "CHAR"},
            {expression = "'äöüÄÖÜßèé'", expected_value = "äöüÄÖÜßèé", expected_type = "CHAR"},
            {expression = "'😀👍'", expected_value = "😀👍", expected_type = "CHAR"},
            {expression = cast("'abc'", "CHAR(5)"), expected_value = "abc  ", expected_type = "CHAR"},
            {
                expression = cast("'äöüÄÖÜßèé'", "CHAR(10)"),
                expected_value = "äöüÄÖÜßèé ",
                expected_type = "CHAR"
            }, {expression = cast("'😀👍'", "CHAR(5)"), expected_value = "😀👍   ", expected_type = "CHAR"},
            {expression = cast("'abc'", "VARCHAR(5)"), expected_value = "abc", expected_type = "VARCHAR"}, --
            {
                expression = cast("'äöüÄÖÜßèé'", "VARCHAR(20)"),
                expected_value = "äöüÄÖÜßèé",
                expected_type = "VARCHAR"
            }, --
            {expression = cast("'😀👍'", "VARCHAR(5)"), expected_value = "😀👍", expected_type = "VARCHAR"}, --
            --
            -- Date/time types
            --
            {expression = cast("'2022-05-31'", "DATE"), expected_value = "2022-05-31", expected_type = "DATE"}, {
                expression = cast("'2021-12-31 23:59:59.999'", "TIMESTAMP"),
                expected_value = "2021-12-31 23:59:59.999000",
                expected_type = "TIMESTAMP"
            }, {
                expression = cast("'2021-12-31 23:59:59.999'", "TIMESTAMP WITH LOCAL TIME ZONE"),
                expected_value = "2021-12-31 23:59:59.999000",
                expected_type = "TIMESTAMP WITH LOCAL TIME ZONE"
            }, --
            --
            -- Interval types
            --
            {
                expression = cast("'5-3'", "INTERVAL YEAR TO MONTH"),
                expected_value = "+05-03",
                expected_type = "INTERVAL YEAR TO MONTH"
            }, {
                expression = cast("'2 12:50:10.123'", "INTERVAL DAY TO SECOND"),
                expected_value = "+02 12:50:10.123",
                expected_type = "INTERVAL DAY TO SECOND"
            }, --
            --
            -- Hashtype type
            --
            {
                expression = cast("'550e8400-e29b-11d4-a716-446655440000'", "HASHTYPE"),
                expected_value = "550e8400e29b11d4a716446655440000",
                expected_type = "HASHTYPE"
            }, --
            --
            -- Geospatial types
            --
            {expression = cast("'POINT(1 2)'", "GEOMETRY"), expected_value = "POINT (1 2)", expected_type = "GEOMETRY"},
            {
                expression = cast("'POINT(1 2)'", "GEOMETRY(1234)"),
                expected_value = "POINT (1 2)",
                expected_type = "GEOMETRY"
            }
        }
        for _, test in ipairs(test_cases) do
            it("Expression " .. test.expression .. " has type " .. test.expected_type, function()
                local cur = assert(connection:execute("select " .. test.expression))
                finally(function()
                    assert.is_true(cur:close())
                end)
                assert.is_same(test.expected_value, cur:fetch()[1])
                assert.is_same(test.expected_type, cur:getcoltypes()[1])
            end)
        end
    end)

    describe("Timestamp and timezone", function()
        local schema_name
        before_each(function()
            schema_name = string.format("TIMESTAMP_TEST_%d", os.time())
            log.debug("Creating schema %s", schema_name)
            assert(connection:execute(string.format("DROP SCHEMA IF EXISTS %s CASCADE", schema_name)))
            assert(connection:execute(string.format("CREATE SCHEMA %s", schema_name)))
        end)

        after_each(function()
            log.debug("Dropping schema %s", schema_name)
            assert(connection:execute(string.format("drop schema %s cascade", schema_name)))
            schema_name = nil
        end)

        local function create_table(column_type)
            local table_name = string.format("%s.%s", schema_name, "tab")
            assert(connection:execute(string.format("CREATE TABLE %s (col %s)", table_name, column_type)))
            return table_name
        end

        local function get_session_timezone()
            local cur = assert(connection:execute("select sessiontimezone"))
            local timezone = cur:fetch()[1]
            cur:close()
            return timezone
        end

        local function set_session_timezone(timezone)
            if timezone then
                local timezone_before = get_session_timezone()
                assert(connection:execute(string.format("ALTER SESSION SET TIME_ZONE = '%s'", timezone)))
                local timezone_after = get_session_timezone()
                log.debug("Timezone before: %s, afterwards: %s", timezone_before, timezone_after)
                assert.is_same(timezone, timezone_after, "Setting session timezone failed")
            end
        end

        local function insert_value_utc(table_name, value)
            set_session_timezone("UTC")
            assert(connection:execute(string.format("INSERT INTO %s (col) VALUES ('%s')", table_name, value)))
        end

        local test_cases = {
            {
                value = "2021-12-31 23:59:59.999",
                column_type = "TIMESTAMP",
                session_timezone = nil,
                expected_value = "2021-12-31 23:59:59.999000"
            }, {
                value = "2021-12-31 23:59:59.999",
                column_type = "TIMESTAMP WITH LOCAL TIME ZONE",
                session_timezone = nil,
                expected_value = "2021-12-31 23:59:59.999000"
            }, {
                value = "2021-12-31 23:59:59.999",
                column_type = "TIMESTAMP",
                session_timezone = "EUROPE/BERLIN",
                expected_value = "2021-12-31 23:59:59.999000"
            }, {
                value = "2021-12-31 23:59:59.999",
                column_type = "TIMESTAMP WITH LOCAL TIME ZONE",
                session_timezone = "EUROPE/BERLIN",
                expected_value = "2022-01-01 00:59:59.999000"
            }, {
                value = "2021-12-31 23:59:59.999",
                column_type = "TIMESTAMP",
                session_timezone = "ASIA/SHANGHAI",
                expected_value = "2021-12-31 23:59:59.999000"
            }, {
                value = "2021-12-31 23:59:59.999",
                column_type = "TIMESTAMP WITH LOCAL TIME ZONE",
                session_timezone = "ASIA/SHANGHAI",
                expected_value = "2022-01-01 07:59:59.999000"
            }
        }

        for _, test in ipairs(test_cases) do
            it(string.format("Timestamp %q in session timezone %q and column type %q has value %q", test.value,
                             test.session_timezone, test.column_type, test.expected_value), function()
                local table_name = create_table(test.column_type)
                insert_value_utc(table_name, test.value)
                set_session_timezone(test.session_timezone)
                local cur = assert(connection:execute("select col from " .. table_name))
                finally(function()
                    assert.is_true(cur:close())
                end)
                assert.is_same(test.expected_value, cur:fetch()[1])
            end)
        end
    end)
end)
