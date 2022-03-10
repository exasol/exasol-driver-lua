local M = {}

-- luacheck: globals wsopen wssend wsreceive wsclose
require("luws")
local exaerror = require("exaerror")
local log = require("remotelog")
local websocket_datahandler = require("websocket_datahandler")

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

local function connect_with_retry(url, options, remaining_retries)
    log.trace("Connecting to websocket url %s with %d remaining retries", url,
              remaining_retries)
    local connection = M:new()
    local websocket, err = wsopen(url, function(conn, opcode, message)
        connection.data_handler:handle_data(conn, opcode, message)
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
            return connect_with_retry(url, options, remaining_retries)
        end
    end
    log.trace("Connected to websocket with result %s", websocket)
    connection.websocket = websocket
    return connection
end

function M.connect(url, options)
    options = options or {}
    return connect_with_retry(url, options, 3)
end

function M:wait_for_response()
    log.trace("Waiting for response")
    local start = os.clock()
    local result, err = wsreceive(self.websocket)
    while result == false and err == 0 do
        result, err = wsreceive(self.websocket)
    end
    if err and type(err) == "string" then
        exaerror.create("E-EDL-4", "Error receiving data: {{error}}",
                        {error = err}):raise()
    end
    if self.data_handler:has_received_data() then
        log.trace(
            "Waiting finished with result false after %fs, received %d bytes",
            os.clock() - start, err)
        return
    end
    log.trace("Wsreceive: result=%s, error=%s. Try again.", result, err)
    self:wait_for_response()
end

function M:send_raw(payload)
    self.data_handler:expect_data()
    local _, err = wssend(self.websocket, 1, payload)
    if err ~= nil then
        exaerror.create("E-EDL-3", "Error sending payload: {{error}}",
                        {error = err}):raise()
    end

    self:wait_for_response()
    self.data_handler:expected_data_received()
    return self.data_handler:get_data()
end

function M:is_connected() return self.websocket and self.websocket.connected end

function M:close()
    if self.closed then return end
    log.trace("Closing websocket")
    wsclose(self.websocket)
    self.closed = true
end

return M
