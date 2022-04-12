-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")
local cursor = require("cursor")

--- This class represents a database connection that provides methods for interacting with the database,
--- e.g. executing queries.
--- @class Connection
--- @field private websocket ExasolWebsocket the websocket
--- @field private session_id string the session ID for this connection
local Connection = {}

--- Create a new instance of the Connection class.
--- @param websocket ExasolWebsocket websocket connection to the database
--- @param session_id string session ID of the current database connection
--- @return Connection connection the new instance
function Connection:create(websocket, session_id)
    log.trace("Created new connection with session ID %d", session_id)
    local object = {websocket = websocket, session_id = session_id, closed = false, cursors = {}}
    self.__index = self
    setmetatable(object, self)
    return object
end

--- Verify that this connection is open before executing an operation
--- @param operation string the operation to be executed (used in the potential error message)
--- @raise an error if this connection is closed
function Connection:_verify_connection_open(operation)
    if self.closed then
        exaerror.create("E-EDL-12", "Connection already closed when trying to call {{operation}}",
                        {operation = operation}):raise()
    end
end

--- Executes the given SQL statement.
--- @param statement string the SQL statement to execute
--- @return Cursor|number|nil result a Cursor object if there are results, the number of rows affected by the command
---   or nil in case there was an error executing the statement
--- @return nil|string|table error in case there was an error executing the statement or nil if the statement
---   was executed successfully
--- [impl -> dsn~luasql-connection-execute~0]
function Connection:execute(statement)
    self:_verify_connection_open("execute")
    log.trace("Executing statement '%s'", statement)
    local result, err = self.websocket:send_execute(statement)
    if err then
        return nil, exaerror.create("E-EDL-6", "Error executing statement {{statement}}: {{error|uq}}",
                                    {statement = statement, error = tostring(err)})
    end
    local num_results = result.numResults
    if num_results == 0 then
        local args = {statement = statement}
        exaerror.create("E-EDL-7", "Got no results for statement {{statement}}", args):add_ticket_mitigation():raise()
    end
    if num_results > 1 then
        return nil,
               exaerror.create("E-EDL-8",
                               "Got {{numResults}} results for statement {{statement}} but at most one is supported",
                               {numResults = num_results, statement = statement}):add_mitigations(
                       "Use only statements that return a single result")
    end
    local first_result = result.results[1]
    local result_type = first_result.resultType
    if result_type == "rowCount" then return first_result.rowCount, nil end
    if result_type ~= "resultSet" then
        local args = {result_type = result_type or "nil"}
        exaerror.create("E-EDL-9", "Got unexpected result type {{result_type}}", args):add_ticket_mitigation():raise()
    end
    local cur = cursor:create(self.websocket, self.session_id, first_result.resultSet)
    table.insert(self.cursors, cur)
    return cur
end

--- Commits the current transaction.
--- @return boolean success <code>true</code> in case of success and false when the operation could not be performed
--- [impl -> dsn~luasql-connection-commit~0]
function Connection:commit()
    self:_verify_connection_open("commit")
    error("Commit will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14")
end

--- Rolls back the current transaction.
--- @return boolean success true in case of success and false when the operation could not be performed
--- [impl -> dsn~luasql-connection-rollback~0]
function Connection:rollback()
    self:_verify_connection_open("rollback")
    error("Rollback will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14")
end

--- Turns on or off the "auto commit" mode.
--- @param autocommit boolean true to enable auto commit, false to disable auto commit
--- @return boolean success true in case of success and false when the operation could not be performed
--- [impl -> dsn~luasql-connection-setautocommit~0]
-- luacheck: ignore 212 # unused argument autocommit
function Connection:setautocommit(autocommit)
    self:_verify_connection_open("setautocommit")
    error("Setautocommit will be implemented in https://github.com/exasol/exasol-driver-lua/issues/24")
end

--- Closes this connection and all cursors created using this connection.
--- @return boolean success true in case of success and false in case of failure
-- [impl -> dsn~luasql-connection-close~0]
function Connection:close()
    if self.closed then
        log.warn("Connection with session ID %d already closed", self.session_id)
        return true
    end
    local cursors = self.cursors
    log.debug("Closing Session session %d and its %d cursors", self.session_id, #cursors)
    for _, cur in ipairs(cursors) do cur:close() end
    local err = self.websocket:send_disconnect()
    if err then
        exaerror.create("E-EDL-11", "Error closing session {{session_id}}: {{error}}",
                        {session_id = self.session_id, error = err}):raise()
    end
    self.websocket:close()
    self.closed = true
    return true
end

return Connection
