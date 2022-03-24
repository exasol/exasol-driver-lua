-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")
local cursor = require("cursor")

-- luacheck: ignore 212 # unused argument self

local M = {}

function M:create(websocket, session_id)
    log.trace("Created new connection with session ID %d", session_id)
    local object = {websocket = websocket, session_id = session_id, closed = false, cursors = {}}
    self.__index = self
    setmetatable(object, self)
    return object
end

function M:_verify_connection_open(operation)
    if self.closed then
        exaerror.create("E-EDL-12", "Connection already closed when trying to call {{operation}}",
                        {operation = operation}):raise()
    end
end

-- [impl -> dsn~luasql-connection-execute~0]
function M:execute(statement)
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

-- [impl -> dsn~luasql-connection-commit~0]
function M:commit()
    self:_verify_connection_open("commit")
    error("Commit will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14")
end

-- [impl -> dsn~luasql-connection-rollback~0]
function M:rollback()
    self:_verify_connection_open("rollback")
    error("Rollback will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14")
end

-- [impl -> dsn~luasql-connection-setautocommit~0]
function M:setautocommit(autocommit)
    self:_verify_connection_open("setautocommit")
    error("Setautocommit will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14")
end

-- [impl -> dsn~luasql-connection-close~0]
function M:close()
    if self.closed then
        log.warn("Connection with session ID %d already closed", self.session_id)
        return
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
end

return M
