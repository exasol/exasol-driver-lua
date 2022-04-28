-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")

-- This class is registered as a callback for incoming messages when connecting to a websocket.
-- It collects incoming messages and logs warnings in case a websocket error occurs.
-- @class WebsocketDatahandler
-- @field private expecting_data boolean flag indicating if we are expecting to receive data from the websocket or not
-- @field private data table a list for collecting all data received from the websocket
local WebsocketDatahandler = {}

-- Create a new instance of the WebsocketDatahandler class.
-- @return WebsocketDatahandler a new instance
function WebsocketDatahandler:create()
    local object = {expecting_data = false, data = {}}
    self.__index = self
    setmetatable(object, self)
    return object
end

-- Checks if the given websocket opcode represents an error or not.
-- @param opcode boolean|number the received websocket opcode
-- @return boolean <code>true</code> if the opcode represents an error that should be logged
local function is_websocket_error(opcode)
    -- LuWS uses false to indicate an error
    return type(opcode) == "boolean" and opcode == false
end

-- Callback function for handling data received from a websocket. This method collects valid
-- data in a list and logs and logs a warning in case an error was received.
-- @param conn table the websocket connection
-- @param opcode boolean|number the websocket opcode. See https://datatracker.ietf.org/doc/html/rfc6455#section-11.8
-- for details about opcodes
-- @param message string the received message
-- @raise an error in case we where not expecting to receive any data
function WebsocketDatahandler:handle_data(conn, opcode, message)
    if is_websocket_error(opcode) then
        log.warn("Received error from websocket connection %s: '%s'", conn, message)
        return
    end
    if not self.expecting_data then
        local err = exaerror.create("E-EDL-5", "Not expecting data from websocket but received message " ..
                                            "with opcode {{opcode}} and data {{message}}",
                                    {opcode = tostring(opcode), message = message}):add_ticket_mitigation()
        log.warn(tostring(err))
        return
    end
    table.insert(self.data, message)
    log.trace("Received message #%d with opcode %s and %d bytes of data: '%s'.", #self.data, opcode, #message, message)
end

-- Tell this handler that we are expecting incoming data,
-- e.g. if we are waiting for a response after sending a request.
-- This also resets the collected data to start a fresh collection.
function WebsocketDatahandler:expect_data()
    log.trace("Expecting to receive data")
    self.expecting_data = true
    self.data = {}
end

-- Tell this handler hat we have received the expected data,
-- e.g. when the response for a request has been received.
function WebsocketDatahandler:expected_data_received()
    log.trace("Stop expecting data, received %d messages", #self.data)
    self.expecting_data = false
end

-- Get all message data collected by this handler.
-- @return string|nil the concatenated received messages or nil if no message was received
function WebsocketDatahandler:get_data()
    if #self.data == 0 then
        log.debug("No messages received since collection started")
        return nil
    end
    log.trace("Received %d messages", #self.data)
    return table.concat(self.data)
end

-- Check if this handler has received any data.
-- @return boolean <code>true</code> if at least one message was received
function WebsocketDatahandler:has_received_data() return #self.data > 0 end

return WebsocketDatahandler
