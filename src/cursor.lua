-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")

-- luacheck: no unused args

local FETCH_MODE_NUMERIC_INDICES = "n"
local FETCH_MODE_ALPHANUMERIC_INDICES = "a" -- luacheck: ignore 211 # unused variable

local M = {}

local function col_index_provider(col_index) return col_index end

local function create_col_name_provider(column_names) return function(col_index) return column_names[col_index] end end

local function get_column_names(result_set)
    if #result_set.columns ~= result_set.numColumns then
        local args = {expected_col_count = result_set.numColumns, actual_col_count = #result_set.columns}
        exaerror.create("E-EDL-24", "Result set reports {{expected_col_count}} but only " ..
                                "{{actual_col_count}} columns are available", args):add_ticket_mitigation():raise()
    end
    local names = {}
    for _, column in ipairs(result_set.columns) do table.insert(names, column.name) end
    return names
end

function M:create(websocket, session_id, result_set)
    local column_names = get_column_names(result_set)
    local object = {
        websocket = websocket,
        session_id = session_id,
        result_set_handle = result_set.resultSetHandle,
        num_columns = result_set.numColumns,
        num_rows = result_set.numRows,
        num_rows_in_message = result_set.numRowsInMessage,
        col_name_provider = create_col_name_provider(column_names),
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

function M:_get_col_name_provider(modestring)
    modestring = modestring or FETCH_MODE_NUMERIC_INDICES
    if modestring ~= FETCH_MODE_NUMERIC_INDICES then
        return self.col_name_provider
    else
        return col_index_provider
    end
end

function M:_fill_row(table, modestring)
    log.trace("Fetching row %d of %d with mode %s", self.current_row, self.num_rows, modestring)
    local col_name_provider = self:_get_col_name_provider(modestring)
    for col = 1, self.num_columns do
        local col_name = col_name_provider(col)
        if not col_name then
            local args = {index = col}
            exaerror.create("E-EDL-23", "No column name found for index {{index}}", args):add_ticket_mitigation()
                    :raise()
        end
        table[col_name] = self.data[col][self.current_row]
    end
end

-- [impl -> dsn~luasql-cursor-fetch~0]
function M:fetch(table, modestring)
    if self.closed then
        exaerror.create("E-EDL-13", "Cursor closed while trying to fetch datasets from cursor"):raise()
    end
    if self.current_row > self.num_rows then
        log.trace("End of result set reached, no more rows after %d", self.num_rows)
        return nil
    end
    table = table or {}
    self:_fill_row(table, modestring)
    self.current_row = self.current_row + 1
    return table
end

-- [impl -> dsn~luasql-cursor-getcolnames~0]
function M:getcolnames()
    error("getcolnames will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14")
end

-- [impl -> dsn~luasql-cursor-getcoltypes~0]
function M:getcoltypes()
    error("getcoltypes will be implemented in https://github.com/exasol/exasol-driver-lua/issues/14")
end

-- [impl -> dsn~luasql-cursor-close~0]
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
