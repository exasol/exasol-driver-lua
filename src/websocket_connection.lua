local M = {}

local luws = require("luws")
local socket = require("socket")
local lunajson = require("lunajson")
local exaerror = require("exaerror")

function M:new(object)
    object = object or {}
    self.__index = self
    setmetatable(object, self)
    return object
end

local function default_data_handler(socket, status, message)
    error("No data handler registered for handling websocket data")
end

function M.connect(wsUrl, options)
    options = options or {}
    local connection = M:new()
    connection.data_handler = default_data_handler
    print("Connecting to ", wsUrl)
    local result, err = wsopen(wsUrl, function(socket, status, message)
        connection.data_handler(socket, status, message)
    end, options)
    if err ~= nil then
        exaerror.create("E-EDL-1", "Error connecting to {{url}}: {{error}}",
                        {url = wsUrl, error = err}):raise()
    end
    print("Connected successfully", result)
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

local function sleep(milliseconds)
    socket.sleep(milliseconds / 1000)
end

function M:waitForResponse()
    sleep(10)
    local result, err = wsreceive(self.websocket)
    if type(err) == "string" then
        exaerror.create("E-EDL-4", "Error receiving data: {{error}}",
                        {error = err}):raise()
    end
    if result == false then
        return -- no more data
    end
    self:waitForResponse()
end

function M:sleepForResponse()
    sleep(100)
    local result, err = wsreceive(self.websocket)
    print("WS Receive finished", result, err)
end

function M:sendRaw(payload)
    local data = nil
    self.data_handler = function(socket, status, message)
        data = message
    end
    local result, err = wssend(self.websocket, 1, payload)
    if err ~= nil then
        exaerror.create("E-EDL-3", "Error sending payload: {{error}}",
                        {error = err}):raise()
    end
    self:waitForResponse()
    --self:sleepForResponse()
    self.data_handler = default_data_handler
    return data
end

function M:close() wsclose(self.websocket) end

return M
