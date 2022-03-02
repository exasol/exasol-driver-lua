local log = require("remotelog")

-- luacheck: no unused args

local M = {}

local cursor = require("cursor")

function M:new(websocket, details)
    log.trace("Created new connection")
    local object = {websocket = websocket, details = details, cursors = {}}
    self.__index = self
    setmetatable(object, self)
    return object
end

function M:execute(statement)
    log.trace("Executing statement '%s'", statement)
    local cur = cursor:new()
    table.insert(self.cursors, cur)
    return cur
end

function M:commit() end

function M:rollback() end

function M:setautocommit(autocommit) end

function M:close()
    log.trace("Closing connection with session id %s: close", self.details.sessionId)
    for _, cur in ipairs(self.cursors) do
        cur:close()
    end
    self.websocket:close()
end

return M
