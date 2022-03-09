local M = {}

-- luacheck: globals wsopen wssend wsreceive wsclose
require("luws")
local socket = require("socket")
local exaerror = require("exaerror")
local log = require("remotelog")

function M:new(object)
    object = object or {}
    object.closed = false
    self.__index = self
    setmetatable(object, self)
    return object
end

local function default_data_handler(message)
    exaerror.create("E-EDL-5",
                    "No data handler registered for handling websocket data {{message}}",
                    {message = message}):add_ticket_mitigation():raise()
end

function M.connect(url, options)
    options = options or {}
    local connection = M:new()
    connection.data_handler = default_data_handler
    log.trace("Connecting to websocket url %s", url)
    local result, err = wsopen(url, function(_, _, message)
        connection.data_handler(message)
    end, options)
    if err ~= nil then
        exaerror.create("E-EDL-1", "Error connecting to {{url}}: {{error}}",
                        {url = url, error = err}):raise()
    end
    log.trace("Connected to websocket with result %s", result)
    connection.websocket = result
    return connection
end

local function sleep(milliseconds) socket.sleep(milliseconds / 1000) end

function M:wait_for_response()
    log.trace("Waiting for response")
    sleep(50)
    local result, err = wsreceive(self.websocket)
    if type(err) == "string" then
        exaerror.create("E-EDL-4", "Error receiving data: {{error}}",
                        {error = err}):raise()
    end
    if result == false then
        return -- no more data
    end
    log.trace("Response not received yet, result=%s, error=%s. Try again",
              result, err)
    self:wait_for_response()
end

function M:send_raw(payload, ignore_response)
    local data = nil
    self.data_handler = function(message) data = message end
    local _, err = wssend(self.websocket, 1, payload)
    if err ~= nil then
        exaerror.create("E-EDL-3", "Error sending payload: {{error}}",
                        {error = err}):raise()
    end
    if ignore_response then
        log.trace("Ignoring response, no need to wait")
        return nil
    else
        self:wait_for_response()
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
