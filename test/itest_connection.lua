local luaunit = require("luaunit")
local driver = require("luasqlexasol")
local config = require("config")

TestConnection = {}

function TestConnection:test_version()
    luaunit.assertEquals(driver.VERSION, "0.1.0")
end

function TestConnection:test_connection_fails()
    local real_connection = config.get_connection_params()
    local tests = {
        {
            props = config.get_connection_params({host = "wronghost", port = "1234"}),
            expected_error_pattern = ".*E%-EDL%-1: Error connecting to 'wss://wronghost:1234': .*"
        }, {
            props = config.get_connection_params({port = "1234"}),
            expected_error_pattern = ".*E%-EDL%-1: Error connecting to 'wss://" ..
                real_connection.host .. ":1234': .*"
        }, {
            props = config.get_connection_params({user = "unknownUser"}),
            expected_error_pattern = ".*E%-EDL%-2: Did not receive response for payload.*"
        }, {
            props = config.get_connection_params({password = "wrong password"}),
            expected_error_pattern = ".*E%-EDL%-2: Did not receive response for payload.*"
        }
    }
    for _, test in ipairs(tests) do
        local env = config.create_environment()
        local sourcename = test.props.host .. ":" .. test.props.port
        luaunit.assertErrorMsgMatches(test.expected_error_pattern, function()
            env:connect(sourcename, test.props.user, test.props.password)
        end)
        env:close()
    end
end

function TestConnection:test_connection_succeeds()
    local connection = config.create_connection()
    local cursor = connection:execute("select 1")
    luaunit.assertEquals(cursor:fetch(), {1})
    luaunit.assertNil(cursor:fetch())
    connection:close()
end

function TestConnection:test_using_closed_connection_fails()
    local connection = config.create_connection()
    connection:close()
    luaunit.assertErrorMsgMatches(".*E%-EDL%-12: Connection already closed", function ()
        connection:execute("select 1")
    end)
end

function TestConnection:test_closing_closed_connection_succeeds()
    local connection = config.create_connection()
    connection:close()
    connection:close()
end

os.exit(luaunit.LuaUnit.run())
