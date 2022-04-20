-- luacheck: globals wsopen wssend wsreceive wsclose
require("luws")
local exaerror = require("exaerror")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local websocket_datahandler = require("websocket_datahandler")

--- The number of retries when connection to the data fails.
local CONNECT_RETRY_COUNT<const> = 3
--- The maximum time in seconds to wait for a response after sending a request.
local RECEIVE_TIMEOUT_SECONDS<const> = 5

--- This class represents a websocket connection that allows sending and receiving messages.
--- @class Websocket
--- @field private data_handler WebsocketDatahandler the handler for receiving messages
local Websocket = {}

--- Creates a new instance of this class that is not yet opened/connected.
--- @return Websocket the new websocket.
local function create()
    local object = {data_handler = websocket_datahandler:create()}
    object.closed = false
    Websocket.__index = Websocket
    setmetatable(object, Websocket)
    return object
end

--- Check if the given error received during connection is recoverable, i.e. we can try to connect again later.
--- @param err string the received error
--- @return boolean <code>true</code> if we can retry the connection, <code>false</code> if this is a permanent error
---   that does not disappear
local function recoverable_connection_error(err) return string.match(err, ".*failed: connection refused$") end

--- Create a connection to a websocket url with the given number of retries.
--- @param url string the websocket url to connect to, e.g. "wss://host:1234"
--- @param websocket_options table the options passed to LuWS when opening a socket,
---                          see https://github.com/toggledbits/LuWS#options for details.
--- @param remaining_retries number the remaining number of retries. If this is 0, there will be no retry.
--- @return Websocket the open websocket connection
--- @raise an error if connection does not succeed after the given number of retries
local function connect_with_retry(url, websocket_options, remaining_retries)
    log.trace("Connecting to websocket url %s with %d remaining retries", url, remaining_retries)
    local connection = create()
    local websocket, err = wsopen(url, function(conn, opcode, message)
        connection.data_handler:handle_data(conn, opcode, message)
    end, websocket_options)
    if err ~= nil then
        if remaining_retries <= 0 or not recoverable_connection_error(err) then
            exaerror.create("E-EDL-1", "Error connecting to {{url}}: {{error}}", {url = url, error = err}):raise()
        else
            remaining_retries = remaining_retries - 1
            log.warn(tostring(exaerror.create("W-EDL-15",
                                              "Websocket connection to {{url}} failed with error {{error}}, " ..
                                                      "remaining retries: {{remaining_retries}}",
                                              {url = url, error = err, remaining_retries = remaining_retries})))
            return connect_with_retry(url, websocket_options, remaining_retries)
        end
    end
    log.trace("Connected to websocket with result %s", websocket)
    connection.websocket = websocket
    return connection
end

--- Open a websocket connection to the given URL, using maximum 3 retries if a connection fails.
--- @param url string the websocket url to connect to, e.g. "wss://host:1234"
--- @return Websocket the open websocket connection
--- @raise an error if connection does not succeed after the given number of retries
function Websocket.connect(url)
    local websocket_options = {receive_timeout = RECEIVE_TIMEOUT_SECONDS}
    log.debug("Connecting to '%s' with %d retries", url, CONNECT_RETRY_COUNT)
    return connect_with_retry(url, websocket_options, CONNECT_RETRY_COUNT)
end

--- Wait until we receive a response.
--- This is implemented with busy waiting until wsreceive indicates that data was received.
--- @param timeout_seconds number the number of seconds to wait for a response
--- @return nil|table <code>nil</code> if a response was received within the timeout or an error if the response
---   did not arrive within the timeout or an error occured while waiting
function Websocket:_wait_for_response(timeout_seconds)
    log.trace("Waiting %ds for response", timeout_seconds)
    local start<const> = os.clock()
    local try_count = 0
    while true do
        local result, err = wsreceive(self.websocket)
        if type(err) == "string" then
            local wrapped_error = exaerror.create("E-EDL-4", "Error receiving data while waiting for response " ..
                                                          "for {{waiting_time}}s: {{error}}",
                                                  {error = err, waiting_time = os.clock() - start})
            wrapped_error.cause = err
            log.error(tostring(wrapped_error))
            return wrapped_error
        end
        local total_wait_time_seconds = os.clock() - start
        if self.data_handler:has_received_data() then
            log.trace("Received result %s after %fs and %d tries", result, total_wait_time_seconds, try_count)
            return nil
        end
        if total_wait_time_seconds >= timeout_seconds then
            return exaerror.create("E-EDL-18", "Timeout after {{waiting_time}}s and {{try_count}} waiting for data",
                                   {waiting_time = total_wait_time_seconds, try_count = try_count})
        end
        try_count = try_count + 1
    end
end

--- Send the given payload and optionally wait for the response and return the response.
--- @param payload string the payload to send
--- @param ignore_response boolean <code>false</code> if we expect a response.
--- @return string the received response or nil if ignore_response was <code>true</code> or an error occurred.
--- @return nil|table <code>nil</code> if the operation was successful, otherwise the error that occured
function Websocket:send_raw(payload, ignore_response)
    if not ignore_response then self.data_handler:expect_data() end
    local _, err = wssend(self.websocket, 1, payload)
    if err == nil then
        if ignore_response then
            log.trace("Ignore response after sending payload '%s'", payload)
            return nil, nil
        end
        err = self:_wait_for_response(RECEIVE_TIMEOUT_SECONDS)
        self.data_handler:expected_data_received()
        if err then
            return nil, err
        else
            return self.data_handler:get_data(), nil
        end
    else
        local args = {payload = payload, error = err}
        exaerror.create("E-EDL-3", "Error sending payload {{payload}}: {{error}}", args):raise()
    end
end

--- Disconnect from the server and close this websocket.
function Websocket:close()
    if self.closed then return end
    log.trace("Closing websocket")
    wsclose(self.websocket)
    self.websocket = nil
    self.closed = true
end

return Websocket
