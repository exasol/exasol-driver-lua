local luaunit = require("luaunit")

local M = {}

function M:new(connection)
    local object = {connection = connection}
    self.__index = self
    setmetatable(object, self)
    return object
end

local function execute(connection, statement)
    local cursor, err = connection:execute(statement)
    if err then luaunit.fail("Expected statement '" .. statement .. "' to succeed but got error " .. tostring(err)) end
    luaunit.assertNotNil(cursor, "Cursor nil after executing statement" .. statement)
    return cursor
end

function M:assert_rows(statement, rows)
    local cursor = execute(self.connection, statement)
    luaunit.assertNotNil(cursor)
    for i, row in ipairs(rows) do luaunit.assertEquals(cursor:fetch(), row, "Row " .. i) end
    luaunit.assertNil(cursor:fetch(), "row not nil after last row")
    cursor:close()
end

function M:assert_execute_fails(statement, expected_error_pattern)
    local cursor, err = self.connection:execute(statement)
    err = tostring(err)
    luaunit.assertStrMatches(tostring(err), expected_error_pattern, 1, #err,
                             "error after executing statement " .. statement)
    luaunit.assertNil(cursor, "cursor is not nil")
end

function M.assert_matches_one_of(value, patterns)
    for _, pattern in ipairs(patterns) do
        if string.match(value, pattern) then
            return
        else
            print("Pattern '" .. pattern .. "' does not match '" .. value .. "'")
        end
    end
    luaunit.fail("Value '" .. value .. "' matched none of the " .. #patterns .. " patterns: " ..
                         table.concat(patterns, ", "))
end

return M
