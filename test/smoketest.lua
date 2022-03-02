local luaunit = require("luaunit")
local driver = require("luasqlexasol")

function test_version() luaunit.assertEquals(driver.VERSION, "0.1.0") end

function test_connection_fails()
    local env = driver.exasol({log_level = "TRACE"})
    luaunit.assertErrorMsgContentEquals(
        "E-EDL-1: Error connecting to 'wss://wronghost:1234': " ..
                "'Connection to wronghost:1234 failed: host or service not provided, or not known'",
        function() env:connect("wronghost:1234", "user", "password") end)
    env:close()
end

os.exit(luaunit.LuaUnit.run())
