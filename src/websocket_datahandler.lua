-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")

local M = {}

function M:create()
    local object = {expecting_data = false, data = {}}
    self.__index = self
    setmetatable(object, self)
    return object
end

local function is_websocket_error(opcode) return type(opcode) == "boolean" and opcode == false end

function M:handle_data(conn, opcode, message)
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

function M:expect_data()
    log.trace("Expecting to receive data")
    self.expecting_data = true
    self.data = {}
end

function M:expected_data_received()
    log.trace("Stop expecting data, received %d messages", #self.data)
    self.expecting_data = false
end

function M:get_data()
    if #self.data == 0 then
        log.debug("No messages received since collection started")
        return nil
    end
    log.trace("Received %d messages", #self.data)
    return table.concat(self.data)
end

function M:has_received_data() return #self.data > 0 end

return M
