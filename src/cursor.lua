local log = require("remotelog")

local M = {}

function M:new()
    local object = {}
    self.__index = self
    setmetatable(object, self)
    return object
end

function M:fetch(table, modestring)
    modestring = modestring or "n"
    table = table or {}

    return table
end

function M:getcolnames() return {} end

function M:getcoltypes() return {} end

function M:close() log.trace("Closing cursor") end

return M
