--- This internal class represents a websocket connection to an Exasol database that
-- provides convenient functions for sending commands and evaluating the result.
-- @classmod luasql.exasol.ExasolWebsocket
-- @field private websocket Websocket the raw websocket
local ExasolWebsocket = {}

local cjson = require("cjson")
local exaerror = require("exaerror")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local raw_websocket = require("luasql.exasol.Websocket")
local constants = require("luasql.exasol.constants")

--- Creates a new Exasol websocket.
-- @tparam luasql.exasol.Websocket websocket the websocket to wrap
-- @treturn luasql.exasol.ExasolWebsocket the new websocket
function ExasolWebsocket._create(websocket)
    local object = {websocket = websocket, closed = false}
    object.closed = false
    ExasolWebsocket.__index = ExasolWebsocket
    setmetatable(object, ExasolWebsocket)
    return object
end

--- Connects to an Exasol database.
-- @tparam string url the websocket URL, e.g. `wss://exasoldb.example.com:8563`
-- @tparam luasql.exasol.ConnectionProperties connection_properties the connection properties
-- @treturn luasql.exasol.ExasolWebsocket the new websocket
function ExasolWebsocket.connect(url, connection_properties)
    local websocket<const> = raw_websocket.connect(url, connection_properties)
    return ExasolWebsocket._create(websocket)
end

--- Sends the login command.
-- See Exasol API documentation for the
-- [`login` command](https://github.com/exasol/websocket-api/blob/master/docs/commands/loginV3.md).
-- This returns a public RSA key used for encrypting the password before sending it with the
-- @{luasql.exasol.ExasolWebsocket:send_login_credentials} method.
-- @treturn table|nil the public RSA key or `nil` if an error occurred
-- @treturn table|nil `nil` if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_login_command()
    log.debug("Sending login command")
    return self:_send_json({command = "login", protocolVersion = 3})
end

--- Sends the login credentials.
-- See Exasol API documentation for the
-- [`login` command](https://github.com/exasol/websocket-api/blob/master/docs/commands/loginV3.md).
-- @tparam string username the username
-- @tparam string encrypted_password the password encrypted with the public key returned by
--   @{luasql.exasol.ExasolWebsocket:send_login_command}
-- @treturn table|nil response data from the database or `nil` if an error occurred
-- @treturn table|nil `nil` if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_login_credentials(username, encrypted_password)
    log.debug("Sending login credentials")
    return self:_send_json({username = username, password = encrypted_password, useCompression = false})
end

--- Sends the disconnect command.
-- See Exasol API documentation for the
-- [`disconnect` command](https://github.com/exasol/websocket-api/blob/master/docs/commands/disconnectV1.md).
-- @treturn table|nil `nil` if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_disconnect()
    log.debug("Sending disconnect command")
    local _, err = self:_send_json({command = "disconnect"}, true)
    return err
end

--- Sends the execute command.
-- See Exasol API documentation for the
-- [`execute` command](https://github.com/exasol/websocket-api/blob/master/docs/commands/executeV1.md).
-- @tparam string statement the SQL statement to execute
-- @treturn table|nil the result set response data from the database or `nil` if an error occurred
-- @treturn table|nil `nil` if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_execute(statement)
    local payload = {command = "execute", sqlText = statement, attributes = {}}
    return self:_send_json(payload)
end

--- Sends the setAttribute command with a given attribute name and value.
-- To set the `null` value for an attribute, use `constants.NULL` or `nil`.
-- Both will be translated to `null` in the JSON command.
-- See Exasol API documentation for the
-- [`setAttributes` command](https://github.com/exasol/websocket-api/blob/master/docs/commands/setAttributesV1.md).
-- @tparam string attribute_name the name of the attribute to set, e.g. `"autocommit"`
-- @tparam string|number|boolean|nil attribute_value the value of the attribute to set, e.g. `false`
-- @treturn table|nil `nil` if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_set_attribute(attribute_name, attribute_value)
    if attribute_value == nil or attribute_value == constants.NULL then attribute_value = cjson.null end
    local _, err = self:_send_json({command = "setAttributes", attributes = {[attribute_name] = attribute_value}})
    return err
end

--- Sends the fetch command.
-- See Exasol API documentation for the
-- [`fetch` command](https://github.com/exasol/websocket-api/blob/master/docs/commands/fetchV1.md).
-- @tparam number result_set_handle result set handle
-- @tparam number start_position row offset (0-based) from which to begin data retrieval
-- @tparam number num_bytes number of bytes to retrieve (max: 64MiB)
-- @treturn table|nil result set from the database or `nil` if an error occurred
-- @treturn table|nil `nil` if the operation was successful, otherwise the error that occured
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

--- Sends the closeResultSet command.
-- See Exasol API documentation for the
-- [`closeResultSet` command](https://github.com/exasol/websocket-api/blob/master/docs/commands/closeResultSetV1.md).
-- @tparam number result_set_handle result set handle to close
-- @treturn table|nil `nil` if the operation was successful, otherwise the error that occured
function ExasolWebsocket:send_close_result_set(result_set_handle)
    local payload = {command = "closeResultSet", resultSetHandles = {result_set_handle}, attributes = {}}
    local _, err = self:_send_json(payload)
    return err
end

--- Extract the error from the given database response.
-- @tparam table response the response from the database
-- @treturn nil|table `nil` the error that occured or `nil` if the response was successful
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
-- and deserialize it from JSON.
-- @tparam table payload the payload to send
-- @tparam boolean|nil ignore_response `false` if we expect a response, else `true`.
--   Default is `false`.
-- @treturn table|nil the received response or nil if ignore_response was `true` or an error occurred
-- @treturn table|nil `nil` if the operation was successful, otherwise the error that occured
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

--- Closes the websocket.
-- @treturn boolean `true` if the operation was successful
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
