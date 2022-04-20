-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")

local DEFAULT_FETCHSIZE_KIB<const> = 128

--- This class represents configuration properties for a database connection.
--- @class ConnectionProperties
--- @field private properties table the websocket
local ConnectionProperties = {}

--- Create a new instance of the Connection class.
--- @param properties table|nil a properties object or <code>nil</code> to use default settings
--- @return Connection connection the new instance
function ConnectionProperties:create(properties)
    log.trace("Created new connection properties")
    properties = properties or {}
    local object = {properties = properties}
    self.__index = self
    setmetatable(object, self)
    object:_validate()
    return object
end

function ConnectionProperties:_validate()
    if self.properties.fetchsize_kb and self.properties.fetchsize_kb <= 0 then
        exaerror.create("E-EDL-27", "Parameter 'fetchsize_kb' must be greater than 0"):add_mitigations(
                "Use a value greater than 0")
    end
end

function ConnectionProperties:get_fetchsize_bytes() --
    return (self.properties.fetchsize_kb or DEFAULT_FETCHSIZE_KB) * 1024
end

return ConnectionProperties
