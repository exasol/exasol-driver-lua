local cjson = require("cjson")
local exaerror = require("exaerror")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local raw_websocket = require("websocket")
local constants = require("constants")

-- This class represents a websocket connection to an Exasol database that provides functions for sending commands.
-- @class ExasolWebsocket
-- @field private websocket Websocket the raw websocket
local ExasolWebsocket = {}

-- Creates a new Exasol websocket.
-- @param websocket Websocket
-- @return ExasolWebsocket the new websocket
function ExasolWebsocket._create(websocket)
    local object = {websocket = websocket, closed = false}
    object.closed = false
    ExasolWebsocket.__index = ExasolWebsocket
    setmetatable(object, ExasolWebsocket)
    return object
end

-- Creates a new Exasol websocket.
-- @param url string the websocket URL, e.g. <code>wss://exasoldb.example.com:8563</code>
-- @param connection_properties ConnectionProperties the connection properties
-- @return ExasolWebsocket the new websocket
function ExasolWebsocket.connect(url, connection_properties)
    local websocket<const> = raw_websocket.connect(url, connection_properties)
    return ExasolWebsocket._create(websocket)
end

-- Sends the login command.
-- See https://github.com/exasol/websocket-api/blob/master/docs/commands/loginV3.md
-- This returns a public RSA key used for encrypting the password before sending it with the
-- send_login_credentials() method.
-- @return table|nil from the database or nil if an error occurred
-- @return table|nil <code>nil</code> if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_login_command()
    log.debug("Sending login command")
    return self:_send_json({command = "login", protocolVersion = 3})
end

-- Sends the login credentials.
-- See https://github.com/exasol/websocket-api/blob/master/docs/commands/loginV3.md
-- @param username string the username
-- @param encrypted_password string the password encrypted with the public key returned by send_login_command()
-- @return table|nil from the database or nil if an error occurred
-- @return table|nil <code>nil</code> if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_login_credentials(username, encrypted_password)
    log.debug("Sending login credentials")
    return self:_send_json({username = username, password = encrypted_password, useCompression = false})
end

-- Sends the disconnect command.
-- See https://github.com/exasol/websocket-api/blob/master/docs/commands/disconnectV1.md
-- @return table|nil <code>nil</code> if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_disconnect()
    log.debug("Sending disconnect command")
    local _, err = self:_send_json({command = "disconnect"}, true)
    return err
end

-- Sends the execute command.
-- See https://github.com/exasol/websocket-api/blob/master/docs/commands/executeV1.md
-- @param statement string the SQL statement to execute
-- @return table|nil from the database or nil if an error occurred
-- @return table|nil <code>nil</code> if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_execute(statement)
    local payload = {command = "execute", sqlText = statement, attributes = {}}
    return self:_send_json(payload)
end

-- Sends the setAttribute command with a given attribute name and value.
-- To set the null value for an attribute, use <code>constants.NULL</code> or <code>nil</code>.
-- Both will be translated to <code>null</code> in the JSON command.
-- See https://github.com/exasol/websocket-api/blob/master/docs/commands/setAttributesV1.md
-- @param attribute_name string the name of the attribute to set, e.g. <code>"autocommit"</code>
-- @param attribute_value any the value of the attribute to set, e.g. <code>false</code>
-- @return table|nil <code>nil</code> if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_set_attribute(attribute_name, attribute_value)
    if attribute_value == nil or attribute_value == constants.NULL then attribute_value = cjson.null end
    local _, err = self:_send_json({command = "setAttributes", attributes = {[attribute_name] = attribute_value}})
    return err
end

-- Sends the fetch command.
-- See https://github.com/exasol/websocket-api/blob/master/docs/commands/fetchV1.md
-- @param result_set_handle number result set handle
-- @param start_position number row offset (0-based) from which to begin data retrieval
-- @param num_bytes number number of bytes to retrieve (max: 64MiB)
-- @return table|nil from the database or nil if an error occurred
-- @return table|nil <code>nil</code> if the operation was successful, otherwise the error that occured
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

-- Sends the closeResultSet command.
-- See https://github.com/exasol/websocket-api/blob/master/docs/commands/closeResultSetV1.md
-- @param result_set_handle number result set handle to close
-- @return table|nil <code>nil</code> if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_close_result_set(result_set_handle)
    local payload = {command = "closeResultSet", resultSetHandles = {result_set_handle}, attributes = {}}
    local _, err = self:_send_json(payload)
    return err
end

-- Extract the error from the given database response
-- @param response table the response from the database
-- @return nil|table <code>nil</code> if the operation was successful, otherwise the error that occured
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

-- Send the given payload serialized to JSON to the database and optionally wait for the response
-- and deserialize it from JSON.
-- @param payload table the payload to send
-- @param ignore_response boolean|nil <code>false</code> if we expect a response, else <code>true</code>.
--   Default is <code>false</code>.
-- @return table|nil the received response or nil if ignore_response was <code>true</code> or an error occurred
-- @return table|nil <code>nil</code> if the operation was successful, otherwise the error that occured
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

-- Closes the websocket.
-- @return boolean <code>true</code> if the operation was successful
function ExasolWebsocket:close()
    if self.closed then
        log.warn(tostring(exaerror.create("W-EDL-37", "Trying to close a Websocket that is already closed")))
        return false
    end
    self.closed = true
    self.websocket:close()
    self.websocket = nil
    return true
end

return ExasolWebsocket
