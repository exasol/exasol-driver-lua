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

function M:execute(statement)
    if self.closed then exaerror.create("E-EDL-12", "Connection already closed"):raise() end
    log.trace("Executing statement '%s'", statement)
    local result, err = self.websocket:send_execute(statement)
    if err then
        return nil, exaerror.create("E-EDL-6", "Error executing statement {{statement}}: {{error|uq}}",
                                    {statement = statement, error = tostring(err)});
    end
    local num_results = result.numResults
    if num_results == 0 then
        exaerror.create("E-EDL-7", "Got no results for statement '{{statement}}'", {statement = statement}):add_ticket_mitigation()
            :raise()
    end
    if num_results > 1 then
        exaerror.create("E-EDL-8",
                        "Got {{numResults}} results for statement '{{statement}}' but at most one is supported",
                        {numResults = num_results, statement = statement}):add_ticket_mitigation():raise()
    end
    local first_result = result.results[1]
    local result_type = first_result.resultType
    if result_type == "rowCount" then return first_result.rowCount, nil end
    if result_type ~= "resultSet" then
        exaerror.create("E-EDL-9", "Got unexpected result type {{resultType}}", {resultType = result_type}):add_ticket_mitigation()
            :raise()
    end
    local cur = cursor:create(self.websocket, self.session_id, first_result.resultSet)
    table.insert(self.cursors, cur)
    return cur
end

function M:commit() error("Commit will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14") end

function M:rollback() error("Rollback will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14") end

function M:setautocommit(autocommit)
    error("Setautocommit will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14")
end

function M:close()
    if self.closed then
        log.warn("Connection with session ID %d already closed", self.session_id)
        return
    end
    local cursors = self.cursors
    log.trace("Closing Session session ID %d: and its %d cursors", #cursors, self.session_id)
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
