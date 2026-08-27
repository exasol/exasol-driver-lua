require("busted.runner")()
local Websocket = require("luasql.exasol.Websocket")

describe("Websocket receive timeout", function()
    -- [utest -> dsn~websocket-safety-deadline~1]
    it("reports the Websocket safety deadline", function()
        local websocket_connection = {
            connected = true,
            options = {receive_timeout = 0},
            socket = {
                settimeout = function()
                end,
                receive = function()
                    return nil, "timeout", ""
                end
            }
        }
        local websocket = {
            websocket = websocket_connection,
            data_handler = {has_received_data = function() return false end}
        }

        local result = Websocket._wait_for_response(websocket, 0)

        assert.matches("E%-EDL%-18: Websocket safety deadline expired after .*s and 0 tries waiting for a response",
                       tostring(result))
    end)
end)
