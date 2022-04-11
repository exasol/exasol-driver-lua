-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")

-- luacheck: no unused args

--- This class represents the result data of a cursor that allows retreiving rows from a result set.
--- @class CursorData
--- @field private data table
--- @field private current_row number
--- @field private current_row_in_batch number
--- @field private num_rows_total number
--- @field private num_rows_in_message number
--- @field private num_rows_fetched_total number
--- @field private result_set_handle string|nil
--- @field private websocket ExasolWebsocket
local CursorData = {}

--- Create a new instance of the CursorData class.
--- @param websocket ExasolWebsocket the websocket connection to the database
--- @param result_set_handle string|nil 
--- @param data table|nil 
--- @param num_rows_total number
--- @param num_rows_in_message number
--- @return CursorData result a new instance
--- @raise an error in case the result set is invalid
function CursorData:create(websocket, result_set_handle, data, num_rows_total, num_rows_in_message)
    local object = {
        websocket = websocket,
        result_set_handle = result_set_handle,
        data = data,
        num_rows_total = assert(num_rows_total, "numRows missing in result set"),
        num_rows_in_message = assert(num_rows_in_message, "numRowsInMessage missing in result set"),
        num_rows_fetched_total = num_rows_in_message,
        current_row = 1,
        current_row_in_batch = 1
    }
    log.trace("Creating cursor data with %d rows in total and %d rows in message", object.num_rows_total,
              object.num_rows_in_message)
    self.__index = self
    setmetatable(object, self)
    return object
end

function CursorData:next_row()
    self.current_row = self.current_row + 1
    self.current_row_in_batch = self.current_row_in_batch + 1
end

function CursorData:get_current_row() return self.current_row end
function CursorData:has_more_rows() return self.current_row <= self.num_rows_total end

function CursorData:get_column_value(column_index)
    self:_fetch_data()
    log.trace("Fetching row %d of %d (%d of %d in current batch)", self.current_row, self.num_rows_total,
              self.current_row_in_batch, self.num_rows_in_message)
    return self.data[column_index][self.current_row_in_batch]
end

function CursorData:_fetch_data()
    if not self.result_set_handle and not self.data then
        exaerror.create("F-EDL-25", "Neither data nor result set handle available"):add_ticket_mitigation():raise()
    end
    if not self.result_set_handle then
        -- Small result set, data already available
        return
    end

    if self.current_row_in_batch > self.num_rows_in_message then self:_fetch_next_data_batch() end
end

function CursorData:_fetch_next_data_batch()
    local start_position = self.current_row - 1
    local num_bytes = 5000
    local response, err = self.websocket:send_fetch(self.result_set_handle, start_position, num_bytes)
    if err then
        exaerror.create("E-EDL-25",
                        "Error fetching result data for handle {{result_set_handle}} with start position {{start_position}} and fetch size {{num_bytes}} bytes",
                        {
            result_set_handle = self.result_set_handle,
            start_position = start_position,
            num_bytes = num_bytes
        }):add_ticket_mitigation():raise()
    end
    self.data = response.data
    self.num_rows_in_message = assert(response.numRows, "missing numRows")
    self.num_rows_fetched_total = self.num_rows_fetched_total + self.num_rows_in_message
    self.current_row_in_batch = 1
    log.debug("Received batch with %d rows (#%d..%d of %d) with start pos %d and fetch size %d bytes", self.num_rows_in_message, self.current_row,
              self.num_rows_fetched_total, self.num_rows_total, start_position, num_bytes)
end

return CursorData