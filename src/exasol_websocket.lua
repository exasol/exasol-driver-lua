local cjson = require("cjson")
local exaerror = require("exaerror")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local raw_websocket = require("websocket")

--- This class represents a websocket connection to an Exasol database that provides functions for sending commands.
--- @class ExasolWebsocket
--- @field private websocket Websocket the raw websocket
local ExasolWebsocket = {}

--- Creates a new Exasol websocket.
--- @param websocket Websocket
--- @return ExasolWebsocket exasol_websocket the new websocket
function ExasolWebsocket._create(websocket)
    local object = {websocket = websocket, closed = false}
    object.closed = false
    ExasolWebsocket.__index = ExasolWebsocket
    setmetatable(object, ExasolWebsocket)
    return object
end

--- Creates a new Exasol websocket.
--- @param url string the websocket URL, e.g."wss://exasoldb.example.com:8563"
--- @return ExasolWebsocket exasolWebsocket the new websocket
function ExasolWebsocket.connect(url)
    local websocket<const> = raw_websocket.connect(url)
    return ExasolWebsocket._create(websocket)
end

--- Sends the login command, see https://github.com/exasol/websocket-api/blob/master/docs/commands/loginV3.md
--- This returns a public RSA key used for encrypting the password before sending it with the
--- send_login_credentials() method.
--- @return table|nil response_data from the database or nil if an error occurred
--- @return string|table|nil err if an error occurred or nil if the operation was successful
function ExasolWebsocket:send_login_command()
    log.debug("Sending login command")
    return self:_send_json({command = "login", protocolVersion = 3})
end

--- Sends the login credentials, see https://github.com/exasol/websocket-api/blob/master/docs/commands/loginV3.md
--- @param username string the username
--- @param encrypted_password string the password encrypted with the public key returned by send_login_command()
--- @return table|nil response_data from the database or nil if an error occurred
--- @return string|table|nil err if an error occurred or nil if the operation was successful
function ExasolWebsocket:send_login_credentials(username, encrypted_password)
    log.debug("Sending login credentials")
    return self:_send_json({username = username, password = encrypted_password, useCompression = false})
end

--- Sends the disconnect command, see https://github.com/exasol/websocket-api/blob/master/docs/commands/disconnectV1.md
--- @return string|table|nil err if an error occurred or nil if the operation was successful
function ExasolWebsocket:send_disconnect()
    log.debug("Sending disconnect command")
    local _, err = self:_send_json({command = "disconnect"}, true)
    return err
end

--- Sends the execute command, see https://github.com/exasol/websocket-api/blob/master/docs/commands/executeV1.md
--- @param statement string the SQL statement to execute
--- @return table|nil response_data from the database or nil if an error occurred
--- @return string|table|nil err if an error occurred or nil if the operation was successful
function ExasolWebsocket:send_execute(statement)
    local payload = {command = "execute", sqlText = statement, attributes = {}}
    return self:_send_json(payload)
end

--- Sends the fetch command, see https://github.com/exasol/websocket-api/blob/master/docs/commands/fetchV1.md
--- @param result_set_handle number the result set handle
--- @param start_position number row offset (0-based) from which to begin data retrieval
--- @param num_bytes number number of bytes to retrieve (max: 64MB)
--- @return table|nil response_data from the database or nil if an error occurred
--- @return string|table|nil err if an error occurred or nil if the operation was successful
function ExasolWebsocket:send_fetch(result_set_handle, start_position, num_bytes)
    local payload = {
        command = "fetch",
        resultSetHandle = result_set_handle,
        startPosition = start_position,
        numBytes = num_bytes,
        attributes = {}
    }
    return self:_send_json(payload)
end

--- Extract the error from the given database response
--- @param response table the response from the database
--- @return nil|table err an error if the response contains an exception or nil if there is no exception
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

--- Send the given payload serialized to JSON to the database and optionally wait for the response
--- and deserialize it from JSON.
--- @param payload table the payload to send
--- @param ignore_response boolean|nil false if we expect a response, else true. Default is false.
--- @return table|nil response_data received response or nil if ignore_response was true or an error occurred
--- @return table|string|nil err if an error occurred or nil if the operation was successful
function ExasolWebsocket:_send_json(payload, ignore_response)
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

--- Closes the websocket
--- @return boolean result true if the operation was successful
function ExasolWebsocket:close()
    if self.closed then
        log.warn("Trying to close a Websocket that is already closed")
        return true
    end
    self.closed = true
    self.websocket:close()
    self.websocket = nil
    return true
end

return ExasolWebsocket
