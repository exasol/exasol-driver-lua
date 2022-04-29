--- This internal module contains common utility functions.
-- @module util
local util = {}

local exaerror = require("exaerror")

--- Make a table read-only be wrapping it in a proxy that raises an error for modifications.
-- See https://www.lua.org/pil/13.4.5.html for details.
function util.read_only(table)
    local proxy = {}
    local metatable = {
        __index = table,
        __newindex = function(_, key, value)
            exaerror.create("E-EDL-32",
                            "Attempt to update read-only table: tried to set key {{key}} to value {{value}}",
                            {key = key, value = value}):raise(3)
        end
    }
    setmetatable(proxy, metatable)
    return proxy
end

return util
