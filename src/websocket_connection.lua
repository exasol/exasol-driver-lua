local M = {}

-- luacheck: globals wsopen wssend wsreceive wsclose
require("luws")
local socket = require("socket")
local lunajson = require("lunajson")
local exaerror = require("exaerror")
local log = require("remotelog")

function M:new()
    local object = {closed = false}
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

local function getResponseError(response)
    if response.status == "ok" then return nil end
    local sqlCode = response.exception and response.exception.sqlCode
    local text = response.text and response.exception.text
    return exaerror.create("E-EDL-10",
                           "Received status {{status}} with code {{sqlCode}}: {{text}}",
                           {
        status = response.status,
        sqlCode = sqlCode,
        text = text
    })
end

function M:sendJson(payload, ignoreResponse)
    local rawPayload = lunajson.encode(payload)
    log.trace("Sending payload '%s'...", rawPayload)
    local rawResponse = self:sendRaw(rawPayload, ignoreResponse)
    if ignoreResponse then
        log.trace("Ignore response, return nil")
        return nil, nil
    end
    if rawResponse == nil then
        exaerror.create("E-EDL-2",
                        "Did not receive response for payload. Username or password may be wrong."):raise()
    end
    log.trace("Received response '%s'", rawResponse)
    local response = lunajson.decode(rawResponse)
    local err = getResponseError(response)
    if err then
        return nil, err
    else
        return response.responseData, nil
    end
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
    log.trace("Response not received yet, result=%s, error=%s. Try again...",
              result, err)
    self:waitForResponse()
end

function M:sendRaw(payload, ignoreResponse)
    local data = nil
    self.data_handler = function(message) data = message end
    local _, err = wssend(self.websocket, 1, payload)
    if err ~= nil then
        exaerror.create("E-EDL-3", "Error sending payload: {{error}}",
                        {error = err}):raise()
    end
    if ignoreResponse then
        log.trace("Ignoring response, no need to wait")
        return nil
    else
        self:waitForResponse()
        self.data_handler = default_data_handler
        return data
    end
end

function M:close()
    if self.closed then return end
    log.trace("Closing websocket")
    wsclose(self.websocket)
    self.closed = true
end

return M
