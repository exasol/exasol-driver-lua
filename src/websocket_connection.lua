local M = {}

-- luacheck: globals wsopen wssend wsreceive wsclose
require("luws")
local socket = require("socket")
local lunajson = require("lunajson")
local exaerror = require("exaerror")
local log = require("remotelog")

function M:new()
    local object = {}
    self.__index = self
    setmetatable(object, self)
    return object
end

local function default_data_handler(message)
    exaerror.create("E-EDL-5",
                    "No data handler registered for handling websocket data {{message}}",
                    {message = message}):add_ticket_mitigation():raise()
end

function M.connect(wsUrl, options)
    options = options or {}
    local connection = M:new()
    connection.data_handler = default_data_handler
    log.trace("Connecting to websocket url %s...", wsUrl)
    local result, err = wsopen(wsUrl, function(_, _, message)
        connection.data_handler(message)
    end, options)
    if err ~= nil then
        exaerror.create("E-EDL-1", "Error connecting to {{url}}: {{error}}",
                        {url = wsUrl, error = err}):raise()
    end
    log.trace("Connected to websocket with result %s", result)
    connection.websocket = result
    return connection
end

function M:sendJson(payload)
    local raw_payload = lunajson.encode(payload)
    local raw_response = self:sendRaw(raw_payload)
    if raw_response == nil then
        exaerror.create("E-EDL-2", "Did not receive response for payload"):raise()
    end
    local response = lunajson.decode(raw_response)
    if response.status ~= "ok" then error("Request failed: " .. raw_response) end
    return response.responseData
end

local function sleep(milliseconds) socket.sleep(milliseconds / 1000) end

function M:waitForResponse()
    log.trace("Waiting for response...")
    sleep(50)
    local result, err = wsreceive(self.websocket)
    if type(err) == "string" then
        exaerror.create("E-EDL-4", "Error receiving data: {{error}}",
        {error = err}):raise()
    end
    if result == false then
        return -- no more data
    end
    log.trace("Response not received yet, result=%s, error=%s. Try again...", result, err)
    self:waitForResponse()
end

function M:sleepForResponse()
    sleep(100)
    local result, err = wsreceive(self.websocket)
    log.trace("Websocket receive finished with result %s / error %s", result, err)
end

function M:sendRaw(payload)
    local data = nil
    self.data_handler = function(message) data = message end
    local _, err = wssend(self.websocket, 1, payload)
    if err ~= nil then
        exaerror.create("E-EDL-3", "Error sending payload: {{error}}",
                        {error = err}):raise()
    end
    self:waitForResponse()
    -- self:sleepForResponse()
    self.data_handler = default_data_handler
    return data
end

function M:close()
    log.trace("Closing websocket")
    wsclose(self.websocket)
end

return M
