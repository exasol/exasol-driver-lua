local log = require("remotelog")
local exaerror = require("exaerror")

-- luacheck: no unused args

local FETCH_MODE_NUMERIC_INDICES = "n"
local FETCH_MODE_ALPHANUMERIC_INDICES = "a" -- luacheck: ignore 211 # unused variable

local M = {}

function M:create(websocket, session_id, result_set)
    local object = {
        websocket = websocket,
        session_id = session_id,
        result_set_handle = result_set.resultSetHandle,
        num_columns = result_set.numColumns,
        num_rows = result_set.numRows,
        num_rows_in_message = result_set.numRowsInMessage,
        columns = result_set.columns,
        data = result_set.data,
        current_row = 1,
        closed = false
    }
    self.__index = self
    setmetatable(object, self)
    if object.result_set_handle then
        error("Result sets with 1000 or more rows are not yet supported, " ..
                  "see https://github.com/exasol/exasol-driver-lua/issues/4")
    end
    return object
end

function M:fetch(table, modestring)
    if self.closed then
        exaerror.create("E-EDL-13",
                        "Cursor closed while trying to fetch datasets from cursor"):raise()
    end
    modestring = modestring or FETCH_MODE_NUMERIC_INDICES
    if modestring ~= FETCH_MODE_NUMERIC_INDICES then
        error("Fetch with modestring '" + modestring +
                  "' is not yet supported, see https://github.com/exasol/exasol-driver-lua/issues/5")
    end
    if self.current_row > self.num_rows then
        log.trace("End of result set reached, no more rows after %d",
                  self.num_rows)
        return nil
    end

    table = table or {}
    log.trace("Fetching row %d of %d with mode %s", self.current_row,
              self.num_rows, modestring)
    for col = 1, self.num_columns do
        table[col] = self.data[col][self.current_row]
    end
    self.current_row = self.current_row + 1
    return table
end

function M:getcolnames()
    error(
        "getcolnames will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14")
end

function M:getcoltypes()
    error(
        "getcoltypes will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14")
end

function M:close()
    if self.closed then
        log.warn("Attempted to close an already closed cursor")
        return
    end
    if self.result_set_handle == nil then
        log.trace("Cursor without result set handle: no need to close")
        self.closed = true
        return
    end
    error("Closing cursor with result set handle not yet supported, " ..
              "see https://github.com/exasol/exasol-driver-lua/issues/4")
    self.closed = true
end

return M
