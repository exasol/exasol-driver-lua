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

local function not_recoverable_connection_error(err)
    return not string.match(err, ".*failed: connection refused$")
end

local function connect_with_retry(url, data_handler, options, remaining_retries)
    local connection = M:new()
    log.trace("Connecting to websocket url %s with %d remaining retries", url,
              remaining_retries)
    local websocket, err = wsopen(url, function(_, _, message)
        connection.data_handler(message)
    end, options)
    if err ~= nil then
        if remaining_retries <= 0 or not_recoverable_connection_error(err) then
            exaerror.create("E-EDL-1", "Error connecting to {{url}}: {{error}}",
                            {url = url, error = err}):raise()
        else
            remaining_retries = remaining_retries - 1
            log.warn(exaerror.create("W-EDL-15",
                                     "Websocket connection to {{ur}} failed with error {{error}}, " ..
                                         "remaining retries: {{remaining_retries}}",
                                     {
                url = url,
                error = err,
                remaining_retries = remaining_retries
            }):__tostring())
            return connect_with_retry(url, data_handler, options,
                                      remaining_retries)
        end
    end
    log.trace("Connected to websocket with result %s", websocket)
    connection.websocket = websocket
    return connection
end

function M.connect(url, options)
    options = options or {}
    return connect_with_retry(url, default_data_handler, options, 3)
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
