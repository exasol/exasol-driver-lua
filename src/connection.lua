local M = {}

local cursor = require("cursor")

function M:new(websocket, details)
    local object = {websocket=websocket, details=details}
    self.__index = self
    setmetatable(object, self)
    return object
end

function M:execute(statement)
    return cursor:new()
end

function M:commit()
end

function M:rollback()
end

function M:setautocommit(autocommit)
end

function M:close()
    print("Closing connection with sessionid ", self.details.sessionId)
end

return M