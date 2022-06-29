local driver = require("luasql.exasol")

local function try_finally(try, finally)
    local ok, result = pcall(try)
    finally()
    if not ok then
        error(result)
    else
        return result
    end
end

local function try_with_closable(closable_creator, try)
    local closeable = closable_creator()
    return try_finally(function()
        return try(closeable)
    end, function()
        closeable:close()
    end)
end

local function execute_query(connection_creator, query, result_processor)
    return try_with_closable(driver.exasol, function(env)
        return try_with_closable(function()
            return connection_creator(env)
        end, function(conn)
            return try_with_closable(function()
                return assert(conn:execute(query))
            end, function(cur)
                return result_processor(cur)
            end)
        end)
    end)
end

local function print_result(cur)
    local result = ""
    result = string.format("%sColumn names: [%s]\n", result, table.concat(cur:getcolnames(), ", "))
    result = string.format("%sColumn types: [%s]\n", result, table.concat(cur:getcoltypes(), ", "))
    local index = 1
    local row = {}
    row = assert(cur:fetch(row, "n"))
    while row ~= nil do
        result = string.format("%sRow %d: [%s]\n", result, index, table.concat(row, ", "))
        row = cur:fetch(row, "n")
        index = index + 1
    end
    return result
end

local function context_connection_creator(ctx)
    return function(env)
        return assert(env:connect(ctx.source_name, ctx.user_name, ctx.password))
    end
end

-- luacheck: globals run -- Required by UDF API
function run(ctx)
    return execute_query(context_connection_creator(ctx), ctx.query, print_result)
end
