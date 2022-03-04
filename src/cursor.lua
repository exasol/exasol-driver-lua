local log = require("remotelog")

-- luacheck: no unused args

local M = {}

function M:new(websocket, sessionId, resultSet)
    local object = {
        websocket = websocket,
        sessionId = sessionId,
        resultSetHandle = resultSet.resultSetHandle,
        numColumns = resultSet.numColumns,
        numRows = resultSet.numRows,
        numRowsInMessage = resultSet.numRowsInMessage,
        columns = resultSet.columns,
        data = resultSet.data,
        currentRow = 1,
        closed = false
    }
    self.__index = self
    setmetatable(object, self)
    if object.resultSetHandle then
        error("Result sets with 1000 or more rows are not yet supported, " ..
                  "see https://github.com/exasol/exasol-driver-lua/issues/4")
    end
    return object
end

function M:fetch(table, modestring)
    modestring = modestring or "n"
    if modestring ~= "n" then
        error("Fetch with modestring '" + modestring +
                  "' is not yet supported, see https://github.com/exasol/exasol-driver-lua/issues/5")
    end
    if self.currentRow > self.numRows then
        log.trace("End of result set reached, no more rows after %d", self.numRows)
        return nil
    end

    table = table or {}
    log.trace("Fetching row %d of %d with mode %s", self.currentRow,
              self.numRows, modestring)
    for col = 1, self.numColumns do
        table[col] = self.data[self.currentRow][col]
    end
    self.currentRow = self.currentRow + 1
    return table
end

function M:getcolnames() return {} end

function M:getcoltypes() return {} end

function M:close()
    if self.closed then
        log.trace("Cursor already closed")
        return
    end
    if self.resultSetHandle == nil then
        log.trace("Cursor without result set handle: no need to close")
        self.closed = true
        return
    end
    error("Closing cursor with result set handle not yet supported, " ..
              "see https://github.com/exasol/exasol-driver-lua/issues/4")
    self.closed = true
end

return M
