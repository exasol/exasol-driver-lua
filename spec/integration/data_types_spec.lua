require("busted.runner")()
local driver = require("luasql.exasol")
local config = require("config")

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

    describe("converted to correct Lua type", function()
        local function cast(expression, type)
            return string.format("cast(%s as %s)", expression, type)
        end
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
            {expression = cast("'äöüÄÖÜßèé'", "CHAR(10)"), expected_value = "äöüÄÖÜßèé ", expected_type = "CHAR"},
            {expression = cast("'😀👍'", "CHAR(5)"), expected_value = "😀👍   ", expected_type = "CHAR"},
            {expression = cast("'abc'", "VARCHAR(5)"), expected_value = "abc", expected_type = "VARCHAR"}, --
            {expression = cast("'äöüÄÖÜßèé'", "VARCHAR(20)"), expected_value = "äöüÄÖÜßèé", expected_type = "VARCHAR"}, --
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
end)
