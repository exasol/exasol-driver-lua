local luaunit = require("luaunit")
local driver = require("luasqlexasol")
local config = require("config")
local log = require("remotelog")
local assertions = require("assertions")

TestConnection = {}

function TestConnection:test_version()
    luaunit.assertEquals(driver.VERSION, "0.1.0")
end

function TestConnection:test_connection_fails()
    local real_connection = config.get_connection_params()
    local tests = {
        {
            props = config.get_connection_params({
                host = "wronghost",
                port = "1234"
            }),
            expected_error_pattern = ".*E%-EDL%-1: Error connecting to 'wss://wronghost:1234': .*"
        }, {
            props = config.get_connection_params({port = "1234"}),
            expected_error_pattern = ".*E%-EDL%-1: Error connecting to 'wss://" ..
                real_connection.host .. ":1234': .*"
        }
    }
    for _, test in ipairs(tests) do
        local env = config.create_environment()
        local sourcename = test.props.host .. ":" .. test.props.port
        luaunit.assertErrorMsgMatches(test.expected_error_pattern, function()
            log.debug("Test: Login to '%s' with user '%s' and password '%s'",
                      sourcename, test.props.user, test.props.password)
            env:connect(sourcename, test.props.user, test.props.password)
        end)
        env:close()
    end
end

function TestConnection:test_login_fails()
    local tests = {
        {props = config.get_connection_params({user = "unknownUser"})},
        {props = config.get_connection_params({password = "wrong password"})}
    }
    for _, test in ipairs(tests) do
        local env = config.create_environment()
        local sourcename = test.props.host .. ":" .. test.props.port
        local _, err = env:connect(sourcename, test.props.user,
                                   test.props.password)
        local error_pattern = "E%-EDL%-16: Login failed: '(E%-%EDL%-%d+:.*)'"
        luaunit.assertStrMatches(tostring(err), error_pattern)
        local cause = string.match(tostring(err), error_pattern)
        assertions.assert_matches_one_of(cause, {
            "E%-EDL%-10: Received DB status 'error' with code 08004: 'Connection exception %- authentication failed%.'",
            "E%-EDL%-4: Error receiving data while waiting for response for [%d%.]+s: 'closed')'"
        })
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
    luaunit.assertErrorMsgMatches(".*E%-EDL%-12: Connection already closed",
                                  function() connection:execute("select 1") end)
end

function TestConnection:test_closing_closed_connection_succeeds()
    local connection = config.create_connection()
    connection:close()
    connection:close()
end

os.exit(luaunit.LuaUnit.run())
