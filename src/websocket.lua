local M = {}

-- luacheck: globals wsopen wssend wsreceive wsclose
require("luws")
local exaerror = require("exaerror")
local log = require("remotelog")
local websocket_datahandler = require("websocket_datahandler")

local CONNECT_RETRY_COUNT = 3
local RECEIVE_TIMEOUT_SECONDS = 5

function M:new(object)
    object = object or {data_handler = websocket_datahandler:create()}
    object.closed = false
    self.__index = self
    setmetatable(object, self)
    return object
end

local function not_recoverable_connection_error(err)
    return not string.match(err, ".*failed: connection refused$")
end

local function connect_with_retry(url, websocket_options, remaining_retries)
    log.trace("Connecting to websocket url %s with %d remaining retries", url,
              remaining_retries)
    local connection = M:new()
    local websocket, err = wsopen(url, function(conn, opcode, message)
        connection.data_handler:handle_data(conn, opcode, message)
    end, websocket_options)
    if err ~= nil then
        if remaining_retries <= 0 or not_recoverable_connection_error(err) then
            exaerror.create("E-EDL-1", "Error connecting to {{url}}: {{error}}",
                            {url = url, error = err}):raise()
        else
            remaining_retries = remaining_retries - 1
            log.warn(tostring(exaerror.create("W-EDL-15",
                                              "Websocket connection to {{url}} failed with error {{error}}, " ..
                                                  "remaining retries: {{remaining_retries}}",
                                              {
                url = url,
                error = err,
                remaining_retries = remaining_retries
            })))
            return connect_with_retry(url, websocket_options, remaining_retries)
        end
    end
    log.trace("Connected to websocket with result %s", websocket)
    connection.websocket = websocket
    return connection
end

function M.connect(url)
    local websocket_options = {receive_timeout = RECEIVE_TIMEOUT_SECONDS}
    log.debug("Connecting to '%s' with %d retries", url, CONNECT_RETRY_COUNT)
    return connect_with_retry(url, websocket_options, CONNECT_RETRY_COUNT)
end

function M:wait_for_response(timeout_seconds)
    log.trace("Waiting %ds for response", timeout_seconds)
    local start = os.clock()
    local try_count = 0
    while true do
        local result, err = wsreceive(self.websocket)
        if type(err) == "string" then
            local wrapped_error = exaerror.create("E-EDL-4",
                                                  "Error receiving data while waiting for response " ..
                                                      "for {{waiting_time}}s: {{error}}",
                                                  {
                error = err,
                waiting_time = os.clock() - start
            })
            wrapped_error.cause = err
            log.error(tostring(wrapped_error))
            return wrapped_error
        end
        local total_wait_time_seconds = os.clock() - start
        if self.data_handler:has_received_data() then
            log.debug("Received result after %fs and %d tries",
                      total_wait_time_seconds, try_count)
            return nil
        end
        if total_wait_time_seconds >= timeout_seconds then
            return exaerror.create("E-EDL-18",
                                   "Timeout after {{waiting_time}}s and {{try_count}} waiting for data",
                                   {
                waiting_time = total_wait_time_seconds,
                try_count = try_count
            })
        end
        try_count = try_count + 1
        log.trace("Wsreceive: result=%s, error=%s. Try again.", result, err)
    end
end

function M:send_raw(payload, ignore_response)
    if not ignore_response then self.data_handler:expect_data() end
    local _, err = wssend(self.websocket, 1, payload)
    if err ~= nil then
        exaerror.create("E-EDL-3", "Error sending payload: {{error}}",
                        {error = err}):raise()
    end
    if ignore_response then
        log.trace("Ignore response after sending payload '%s'", payload)
        return nil, nil
    end
    err = self:wait_for_response(RECEIVE_TIMEOUT_SECONDS)
    self.data_handler:expected_data_received()
    if err then return nil, err end
    return self.data_handler:get_data(), nil
end

function M:is_connected() return self.websocket and self.websocket.connected end

function M:close()
    if self.closed then return end
    log.trace("Closing websocket")
    wsclose(self.websocket)
    self.closed = true
end

return M
