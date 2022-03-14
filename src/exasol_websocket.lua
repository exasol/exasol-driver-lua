local M = {}

local lunajson = require("lunajson")
local exaerror = require("exaerror")
local log = require("remotelog")
local raw_websocket = require("websocket")

function M:create(websocket)
    local object = {websocket = websocket}
    object.closed = false
    self.__index = self
    setmetatable(object, self)
    return object
end

function M.connect(url, options)
    local websocket = raw_websocket.connect(url, options)
    return M:create(websocket)
end

function M:send_login_command()
    return self:_send_json({command = "login", protocolVersion = 3})
end

function M:send_disconnect()
    return self:_send_json({command = "disconnect"}, true)
end

function M:send_login_credentials(username, encrypted_password)
    return self:_send_json({
        username = username,
        password = encrypted_password,
        useCompression = false
    })
end

function M:send_execute(statement)
    return self:_send_json({
        command = "execute",
        sqlText = statement,
        attributes = {}
    })
end

local function get_response_error(response)
    if response.status == "ok" then return nil end
    local sqlCode = response.exception and response.exception.sqlCode
    local text = response.text and response.exception.text
    return exaerror.create("E-EDL-10",
                           "Received status {{status}} with code {{sqlCode|uq}}: {{text|uq}}",
                           {
        status = response.status,
        sqlCode = sqlCode,
        text = text
    })
end

function M:_send_json(payload, ignore_response)
    local raw_payload = lunajson.encode(payload)
    log.trace("Sending payload '%s'", raw_payload)
    local raw_response = self.websocket:send_raw(raw_payload, ignore_response)
    if ignore_response then
        log.trace("Ignore response, return nil")
        return nil, nil
    end
    if raw_response == nil then
        exaerror.create("E-EDL-2",
                        "Did not receive response for Exasol WebSocket request. Username or password may be wrong."):raise()
    end
    log.trace("Received response '%s'", raw_response)
    local response = lunajson.decode(raw_response)
    local err = get_response_error(response)
    if err then
        return nil, err
    else
        return response.responseData, nil
    end
end

function M:close()
    self.websocket:close()
end

return M