local log = require("remotelog")
local exaerror = require("exaerror")

-- luacheck: no unused args

local M = {}

local cursor = require("cursor")

function M:new(websocket, sessionId)
    log.trace("Created new connection with session id %d", sessionId)
    local object = {
        websocket = websocket,
        sessionId = sessionId,
        closed = false,
        cursors = {}
    }
    self.__index = self
    setmetatable(object, self)
    return object
end

function M:execute(statement)
    log.trace("Executing statement '%s'", statement)
    local result, err = self.websocket:sendJson({
        command = "execute",
        sqlText = statement,
        attributes = {}
    })

    if err then
        return nil, exaerror.create("E-EDL-6",
                                    "Error executing statement '{{statement}}': {{error}}",
                                    {
            statement = statement,
            error = tostring(err)
        });
    end
    local numResults = result.numResults
    if numResults == 0 then
        exaerror.create("E-EDL-7",
                        "Got no results for statement '{{statement}}'",
                        {statement = statement}):add_ticket_mitigation():raise()
    end
    if numResults > 1 then
        exaerror.create("E-EDL-8",
                        "Got {{numResults}} results for statement '{{statement}}' but at most one is supported",
                        {numResults = numResults, statement = statement}):add_ticket_mitigation()
            :raise()
    end
    local firstResult = result.results[1]
    local resultType = firstResult.resultType
    if resultType == "rowCount" then return firstResult.rowCount, nil end
    if resultType ~= "resultSet" then
        exaerror.create("E-EDL-9", "Got unexpected result type {{resultType}}",
                        {resultType = resultType}):add_ticket_mitigation()
            :raise()
    end
    local cur =
        cursor:new(self.websocket, self.sessionId, firstResult.resultSet)
    table.insert(self.cursors, cur)
    return cur
end

function M:commit() end

function M:rollback() end

function M:setautocommit(autocommit) end

function M:close()
    if self.closed then
        log.trace("Connection with session id %d already closed", self.sessionId)
        return
    end
    log.trace("Closing connection with session id %d: close cursors", self.sessionId)
    for _, cur in ipairs(self.cursors) do cur:close() end
    local _, err = self.websocket:sendJson({command = "disconnect"}, true)
    if err then
        exaerror.create("E-EDL-11",
                        "Error closing session {{sessionId}}: {{error}}",
                        {sessionId = self.sessionId, error = err})
    end
    self.websocket:close()
    self.closed = true
end

return M
