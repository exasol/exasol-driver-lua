--- Utility functions for creating query result stubs used in unit tests
local resultstub = {}

function resultstub.create_resultset(column_names, rows)
    column_names = column_names or {}
    rows = rows or {}
    local columns = {}
    local data = {}
    for column_index, column_name in ipairs(column_names) do
        table.insert(columns, {name = column_name})
        data[column_index] = {}
        for row_index, row in ipairs(rows) do
            local value = row[column_name]
            if value == nil then error("No value for row " .. row_index .. " column " .. column_name) end
            table.insert(data[column_index], value)
        end
    end
    return {numRows = #rows, numRowsInMessage = #rows, numColumns = #columns, columns = columns, data = data}
end

--- Creates a result set with a result set handle and without row data.
--- The database returns this kind of result for large result sets
--- where we need to fetch the row data in a separate request.
function resultstub.create_batched_resultset(column_names, total_row_count, result_set_handle)
    column_names = column_names or {}
    local columns = {}
    for _, column_name in ipairs(column_names) do table.insert(columns, {name = column_name}) end
    return {
        resultSetHandle = result_set_handle,
        numRows = total_row_count,
        numRowsInMessage = 0,
        numColumns = #columns,
        columns = columns,
        data = nil
    }
end

function resultstub.create_fetch_result(column_names, rows)
    column_names = column_names or {}
    rows = rows or {}
    local columns = {}
    local data = {}
    for column_index, column_name in ipairs(column_names) do
        table.insert(columns, {name = column_name})
        data[column_index] = {}
        for row_index, row in ipairs(rows) do
            local value = row[column_name]
            if value == nil then error("No value for row " .. row_index .. " column " .. column_name) end
            table.insert(data[column_index], value)
        end
    end
    return {numRows = #rows, data = data}
end

return resultstub
