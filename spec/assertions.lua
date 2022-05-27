local assert = require("luassert")
local cjson = require("cjson")
local log = require("remotelog")

local function deep_equals(object1, object2)
    local type1 = type(object1)
    local type2 = type(object2)
    if type1 ~= type2 then
        return false
    end
    if type1 ~= 'table' and type2 ~= 'table' then
        return object1 == object2
    end
    for key1, value1 in pairs(object1) do
        local value2 = object2[key1]
        if value2 == nil or not deep_equals(value1, value2) then
            return false
        end
    end
    for key2, value2 in pairs(object2) do
        local value1 = object1[key2]
        if value1 == nil or not deep_equals(value1, value2) then
            return false
        end
    end
    return true
end

local function is_json(_, arguments)
    local expected = arguments[1]
    if type(expected) == "string" then
        expected = cjson.decode(expected)
    end
    return function(actual)
        if type(actual) ~= "string" then
            log.warn("Expected type string but got %s for value %s", type(actual), actual)
            return false
        end
        actual = cjson.decode(actual)
        log.debug("Compare expected %s with actual %s", expected, actual)
        local equal = deep_equals(actual, expected)
        if not equal then
            log.warn("Expected %s but got %s", cjson.encode(expected), cjson.encode(actual))
        end
        return equal
    end
end

assert:register("matcher", "json", is_json)
