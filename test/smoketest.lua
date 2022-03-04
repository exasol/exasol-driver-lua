local luaunit = require("luaunit")
local driver = require("luasqlexasol")

TestSmokeTest = {}

function TestSmokeTest:test_version() luaunit.assertEquals(driver.VERSION, "0.1.0") end

function TestSmokeTest:test_connection_fails()
    local env = driver.exasol({log_level = "TRACE"})
    luaunit.assertErrorMsgMatches(
        ".*E%-EDL%-1: Error connecting to 'wss://wronghost:1234':.*",
        function() env:connect("wronghost:1234", "user", "password") end)
    env:close()
end

os.exit(luaunit.LuaUnit.run())
