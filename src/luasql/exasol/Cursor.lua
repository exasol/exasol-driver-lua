-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")
local CursorData = require("luasql.exasol.CursorData")

-- luacheck: no unused args

local FETCH_MODE_NUMERIC_INDICES = "n"
local FETCH_MODE_ALPHANUMERIC_INDICES = "a" -- luacheck: ignore 211 # unused variable

--- This class represents a cursor that allows retrieving rows from a result set.
-- @classmod luasql.exasol.Cursor
-- @field private col_name_provider function
-- @field private num_columns number
-- @field private num_rows number
-- @field private data CursorData
-- @field private websocket ExasolWebsocket
-- @field private result_set_handle string|nil
local Cursor = {}

--- This result table index provider returns the column index.
-- This is used for fetch mode "n" (numeric indices in the result table).
-- To avoid creating a new function for each row we create this only once and re-use it.
-- @tparam number col_index the column index
-- @treturn number the column index
local function col_index_provider(col_index) return col_index end

--- This function creates a result table index provider that returns the column name.
-- This is used for fetch mode "a" (alphanumeric indices in the result table).
-- To avoid creating a new function for each row we create this only once in the constructor and re-use it.
-- @tparam table column_names a list of column names
-- @treturn function result table index provider that maps the column index to column names
local function create_col_name_provider(column_names) --
    return function(col_index) --
        return column_names[col_index]
    end
end

--- This function extracts the column names from a result set.
-- @tparam table result_set the result set
-- @treturn table a list of column names
-- @raise an error if the number of columns is not equal to the number reported by the result set
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

--- Extracts the column types from a result set.
-- @tparam table result_set the result set
-- @treturn table a list of column types
local function get_column_types(result_set)
    local types = {}
    local E<const> = {}
    for _, column in ipairs(result_set.columns) do --
        table.insert(types, (column.dataType or E).type)
    end
    return types
end

--- Create a new instance of the Cursor class.
-- @tparam luasql.exasol.ConnectionProperties connection_properties connection properties
-- @tparam luasql.exasol.ExasolWebsocket websocket the websocket connection to the database
-- @tparam string session_id the session ID of the current database connection
-- @tparam table result_set the result set returned by the database
-- @treturn luasql.exasol.Cursor a new Cursor instance
-- @raise an error in case the result set is invalid, e.g. the number of columns or rows is inconsistent
function Cursor:create(connection_properties, websocket, session_id, result_set)
    local column_names = get_column_names(result_set)
    local column_types = get_column_types(result_set)
    local object = {
        websocket = websocket,
        session_id = session_id,
        result_set_handle = result_set.resultSetHandle,
        num_columns = result_set.numColumns,
        num_rows = result_set.numRows,
        column_names = column_names,
        column_types = column_types,
        col_name_provider = create_col_name_provider(column_names),
        data = CursorData:create(connection_properties, websocket, result_set),
        closed = false
    }
    self.__index = self
    setmetatable(object, self)
    return object
end

--- Gets a result table index provider for the given fetch mode.
-- @tparam "a"|"n" modestring the fetch mode: `"a"` for alphanumeric indices, `"n"` for numeric indices
-- @treturn function a function that maps column indices to a table index
--   in the result table
function Cursor:_get_result_table_index_provider(modestring)
    if modestring ~= FETCH_MODE_NUMERIC_INDICES then
        return self.col_name_provider
    else
        return col_index_provider
    end
end

--- Fills the given table with the values of the current row.
-- @tparam table table the table to fill
-- @tparam "a"|"n" modestring determines which indices are used when filling the table:
--   `"a"` for alphanumeric indices, `"n"` for numeric indices
function Cursor:_fill_row(table, modestring)
    local col_name_provider = self:_get_result_table_index_provider(modestring)
    for col = 1, self.num_columns do
        local col_name = col_name_provider(col)
        if not col_name then
            local args = {index = col}
            exaerror.create("E-EDL-23", "No column name found for index {{index}}", args):add_ticket_mitigation()
                    :raise()
        end
        table[col_name] = self.data:get_column_value(col)
    end
end

--- Retrieves the next row of results.
-- If fetch is called without parameters, the results will be returned directly to the caller.
-- If fetch is called with a table, the results will be copied into the table and the changed table will be returned.
-- In this case, an optional modestring parameter can be used. It is a string indicating how the resulting table
-- should be constructed. The mode string can contain:
--
-- * `"n"`: the resulting table will have numerical indices (default)
-- * `"a"`: the resulting table will have alphanumerical indices
--
-- The numerical indices are the positions of the result columns in the `SELECT` statement;
-- the alphanumerical indices are the names of the fields.
--
-- The optional table parameter is a table that should be used to store the next row. This allows
-- the use of a single table for many fetches, which can improve the overall performance.
--
-- A call to fetch after the last row has already being returned, will close the corresponding cursor.
-- The result values are converted to Lua types, i.e. `nil`, number and string.
--
-- Null values from the database are converted `luasql.exasol.NULL`.
-- You can test for it with `value == luasql.exasol.NULL`.
--
-- @tparam table|nil table the table to which the result will be copied or `nil` to return a new table
-- @tparam nil|"a"|"n" modestring the mode as described above
-- @treturn table|nil row data as described above or `nil` if there are no more rows
function Cursor:fetch(table, modestring)
    -- [impl -> dsn~luasql-cursor-fetch~0]
    if self.closed then
        exaerror.create("E-EDL-13", "Cursor closed while trying to fetch datasets from cursor"):raise()
    end
    if not self.data:has_more_rows() then
        log.trace("End of result set reached, no more rows after %d", self.num_rows)
        if not self.closed then self:close() end
        return nil
    end
    table = table or {}
    modestring = modestring or FETCH_MODE_NUMERIC_INDICES
    self:_fill_row(table, modestring)
    self.data:next_row()
    return table
end

--- Gets the list of column names.
-- @treturn table the list of column names
function Cursor:getcolnames()
    -- [impl -> dsn~luasql-cursor-getcolnames~0]
    return self.column_names
end

--- Gets the list of column types.
-- @treturn table the list of column types
function Cursor:getcoltypes()
    -- [impl -> dsn~luasql-cursor-getcoltypes~0]
    return self.column_types
end

--- Closes this cursor.
-- @treturn boolean `true` in case of success and `false` when the cursor is already closed
function Cursor:close()
    -- [impl -> dsn~luasql-cursor-close~0]
    if self.closed then
        log.warn(tostring(exaerror.create("W-EDL-33", "Attempted to close an already closed cursor")))
        return false
    end
    if self.result_set_handle == nil then
        log.trace("Cursor without result set handle: no need to close")
        self.closed = true
        return true
    end

    local err = self.websocket:send_close_result_set(self.result_set_handle)
    if err then
        exaerror.create("E-EDL-28", "Failed to close result set {{result_set_handle}}: {{error}}",
                        {result_set_handle = self.result_set_handle, error = err}):raise()
        return false
    else
        log.trace("Successfully closed result set %d", self.result_set_handle)
        self.closed = true
        return true
    end
end

return Cursor
