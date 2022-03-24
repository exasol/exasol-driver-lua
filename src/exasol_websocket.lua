local M = {}

local cjson = require("cjson")
local exaerror = require("exaerror")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local raw_websocket = require("websocket")

function M._create(websocket)
    local object = {websocket = websocket, closed = false}
    object.closed = false
    M.__index = M
    setmetatable(object, M)
    return object
end

function M.connect(url)
    local websocket<const> = raw_websocket.connect(url)
    return M.create(websocket)
end

function M:send_login_command()
    log.debug("Sending login command")
    return self:_send_json({command = "login", protocolVersion = 3})
end

function M:send_login_credentials(username, encrypted_password)
    log.debug("Sending login credentials")
    return self:_send_json({username = username, password = encrypted_password, useCompression = false})
end

function M:send_disconnect()
    log.debug("Sending disconnect command")
    local _, err = self:_send_json({command = "disconnect"}, true)
    return err
end

function M:send_execute(statement)
    local payload = {command = "execute", sqlText = statement, attributes = {}}
    return self:_send_json(payload)
end

local function get_response_error(response)
    if response.status == "ok" then return nil end
    if response.exception then
        local sqlCode = response.exception.sqlCode or "nil"
        local text = response.exception.text or "nil"
        return exaerror.create("E-EDL-10", "Received DB status {{status}} with code {{sqlCode|uq}}: {{text}}",
                               {status = response.status, sqlCode = sqlCode, text = text})
    else
        return exaerror.create("E-EDL-17", "Received DB status {{status}} without exception details",
                               {status = response.status})
    end
end

function M:_send_json(payload, ignore_response)
    local raw_payload = cjson.encode(payload)
    if self.closed then
        exaerror.create("E-EDL-22", "Websocket already closed when trying to send payload {{payload}}",
                        {payload = raw_payload}):raise()
    end

    log.trace("Sending payload '%s', ignore response=%s", raw_payload, ignore_response)
    local raw_response, err = self.websocket:send_raw(raw_payload, ignore_response)
    if ignore_response then return nil, nil end
    if err then return nil, err end
    if raw_response == nil then
        err = exaerror.create("E-EDL-2", "Did not receive response for request payload {{payload}}.",
                              {payload = raw_payload})
        log.error(tostring(err))
        err:raise()
    end

    log.trace("Received response of %d bytes", #raw_response)
    local response = cjson.decode(raw_response)
    err = get_response_error(response)
    if err then
        return nil, err
    else
        return response.responseData, nil
    end
end

function M:close()
    self.closed = true
    self.websocket:close()
end

return M
