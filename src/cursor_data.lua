-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")
local constants = require("constants")
local cjson = require("cjson")

-- luacheck: no unused args

--- This class represents the result data of a cursor that allows retreiving rows from a result set.
--- It handles large result sets by fetching new batches automatically.
--- @class CursorData
--- @field private data table|nil the data received from the server. May be <code>nil</code> in case of
---   a large result set that requires fetching batches.
--- @field private current_row number the current row number (starting with 1) of the complete result set
--- @field private current_row_in_batch number the current row number (starting with 1) in the current batch
--- @field private num_rows_total number the total row count in the result set
--- @field private num_rows_in_message number the number of rows in the current batch
--- @field private num_rows_fetched_total number the number of rows in all batches fetched until now
--- @field private result_set_handle number|nil the result set handle or <code>nil</code> in case of
---   a small result set
--- @field private websocket ExasolWebsocket the websocket connection to the database
--- @field private connection_properties ConnectionProperties the user defined connection settings,
---   containing e.g. fetch size
local CursorData = {}

--- Create a new instance of the CursorData class.
--- @param connection_properties ConnectionProperties the user defined connection settings, containing e.g. fetch size
--- @param websocket ExasolWebsocket the websocket connection to the database
--- @param result_set table the result set received when executing a query
--- @return CursorData a new CursorData instance
--- @raise an error in case the result set is invalid
function CursorData:create(connection_properties, websocket, result_set)
    local object = {
        websocket = websocket,
        connection_properties = assert(connection_properties, "connection_properties missing"),
        result_set_handle = result_set.resultSetHandle,
        data = result_set.data,
        num_rows_total = assert(result_set.numRows, "numRows missing in result set"),
        num_rows_in_message = assert(result_set.numRowsInMessage, "numRowsInMessage missing in result set"),
        num_rows_fetched_total = result_set.numRowsInMessage,
        current_row = 1,
        current_row_in_batch = 1
    }
    if object.result_set_handle then
        log.debug("Creating cursor data for result set %d with %d rows in total and %d rows in message",
                  object.result_set_handle, object.num_rows_total, object.num_rows_in_message)
    else
        log.debug("Creating cursor data without result set handle with %d rows", object.num_rows_total)
    end
    self.__index = self
    setmetatable(object, self)
    return object
end

--- Advances the cursor data to the next row.
function CursorData:next_row()
    self.current_row = self.current_row + 1
    self.current_row_in_batch = self.current_row_in_batch + 1
end

--- Get the current row number.
--- @return number the current row number (starting with 1) of the complete result set
function CursorData:get_current_row() return self.current_row end

--- Check if there are more rows available in the result set.
--- @return boolean <code>true</code> if there are more rows available
function CursorData:has_more_rows() return self.current_row <= self.num_rows_total end

--- Convert a column value if necessary before returining it.
--- We need to replace <code>cjson.null</code> with <code>luasqlexasol.NULL</code> to hide the implementation
--- detail that we are using cjson for JSON parsing.
local function convert_col_value(col_value)
    if col_value == cjson.null then
        return constants.NULL
    else
        return col_value
    end
end

--- Get a column value from the current row.
--- Fetches the next batch in case not enough data is available.
--- @param column_index number the column index starting with 1
--- @return any the value of the given column
function CursorData:get_column_value(column_index)
    self:_fetch_data()
    log.trace("Fetching row %d of %d (%d of %d in current batch)", self.current_row, self.num_rows_total,
              self.current_row_in_batch, self.num_rows_in_message)
    if column_index <= 0 or #self.data < column_index then
        exaerror.create("E-EDL-29",
                        "Column index {{column_index}} out of bound, must be between 1 and {{column_count}}",
                        {column_index = column_index, column_count = #self.data}):add_ticket_mitigation():raise()
    end
    if #self.data[column_index] < self.current_row_in_batch then
        local message = "Row {{row_index}} out of bound, must be between 1 and {{row_count}}"
        local args = {row_index = self.current_row_in_batch, row_count = #self.data[column_index]}
        exaerror.create("E-EDL-30", message, args):add_ticket_mitigation():raise()
    end
    local value = self.data[column_index][self.current_row_in_batch]
    return convert_col_value(value)
end

--- Fetch the next batch of data if no more rows are available locally.
-- [impl -> dsn~luasql-cursor-fetch-resultsethandle~0]
function CursorData:_fetch_data()
    if not self.result_set_handle and not self.data then
        exaerror.create("F-EDL-25", "Neither data nor result set handle available"):add_ticket_mitigation():raise()
    end
    if not self.result_set_handle then
        -- Small result set, data already available
        return
    end
    if self:_end_of_result_set_reached() then
        exaerror.create("E-EDL-31", "No more rows available in result set"):add_ticket_mitigation():raise()
    end
    if not self:_more_data_available() then self:_fetch_next_data_batch() end
end

function CursorData:_end_of_result_set_reached() return self.current_row > self.num_rows_total end

function CursorData:_more_data_available() return self.current_row_in_batch <= self.num_rows_in_message end

function CursorData:_fetch_next_data_batch()
    log.trace("Fetching next data batch. Current row in batch: %d, rows in message: %d", self.current_row_in_batch,
              self.num_rows_in_message)
    local start_position = self.current_row - 1
    local fetch_size = self.connection_properties:get_fetchsize_bytes()
    local response, err = self.websocket:send_fetch(self.result_set_handle, start_position, fetch_size)
    if err then
        exaerror.create("E-EDL-26",
                        "Error fetching result data for handle {{result_set_handle}} with start position " ..
                                "{{start_position}} and fetch size {{fetch_size_bytes}} bytes: {{error}}", {
            result_set_handle = self.result_set_handle,
            start_position = start_position,
            fetch_size_bytes = fetch_size,
            error = err
        }):raise()
    end
    self.data = assert(response.data, "missing data")
    self.num_rows_in_message = assert(response.numRows, "missing numRows")
    self.num_rows_fetched_total = self.num_rows_fetched_total + self.num_rows_in_message
    self.current_row_in_batch = 1
    log.debug("Received batch with %d rows (#%d..%d of %d) with start pos %d and fetch size %d bytes",
              self.num_rows_in_message, self.current_row, self.num_rows_fetched_total, self.num_rows_total,
              start_position, fetch_size)
end

return CursorData
