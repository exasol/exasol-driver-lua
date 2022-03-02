local M = {}

local luws = require("luws")
local socket = require("socket")
local lunajson = require("lunajson")
local exaerror = require("exaerror")

function M:new(log)
    local object =  {log=log}
    self.__index = self
    setmetatable(object, self)
    return object
end

local function default_data_handler(socket, status, message)
    exaerror.create("E-EDL-5",
                    "No data handler registered for handling websocket data {{message}}",
                    {message = message}):add_ticket_mitigation():raise()
end

function M.connect(log, wsUrl, options)
    options = options or {}
    local connection = M:new(log)
    connection.data_handler = default_data_handler
    log.trace("Connecting to websocket url %s...", wsUrl)
    local result, err = wsopen(wsUrl, function(socket, status, message)
        connection.data_handler(socket, status, message)
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
    self.log.trace("Waiting for response...")
    sleep(50)
    local result, err = wsreceive(self.websocket)
    if type(err) == "string" then
        exaerror.create("E-EDL-4", "Error receiving data: {{error}}",
        {error = err}):raise()
    end
    if result == false then
        return -- no more data
    end
    self.log.trace("Response not received yet, result=%s, error=%s. Try again...", result, err)
    self:waitForResponse()
end

function M:sleepForResponse()
    sleep(100)
    local result, err = wsreceive(self.websocket)
    self.log.trace("Websocket receive finished with result %s / error %s", result, err)
end

function M:sendRaw(payload)
    local data = nil
    self.data_handler = function(socket, status, message) data = message end
    local result, err = wssend(self.websocket, 1, payload)
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
    self.log.trace("Closing websocket")
    wsclose(self.websocket)
end

return M
