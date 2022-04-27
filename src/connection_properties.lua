-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")

local DEFAULT_FETCHSIZE_KIB<const> = 128

--- This class represents configuration properties for a database connection.
--- @class ConnectionProperties
--- @field private properties table the properties
local ConnectionProperties = {}

--- Create a new instance of the Connection class.
--- @param properties table|nil a properties object or <code>nil</code> to use default settings
--- @return Connection connection the new instance
--- @raise error if given properties are not valid
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
    if self.properties.fetchsize_kib and self.properties.fetchsize_kib <= 0 then
        exaerror.create("E-EDL-27", "Parameter 'fetchsize_kib' must be greater than 0"):add_mitigations(
                "Use a value greater than 0"):raise()
    end
end

--- Get the configured fetch size in bytes used when fetching query result data.
--- Configuration property: <code>fetchsize_kib</code>.
--- Default value: <code>131072</code> = <code>128 * 1024</code>.
--- @return number fetchsize in bytes
function ConnectionProperties:get_fetchsize_bytes() --
    return (self.properties.fetchsize_kib or DEFAULT_FETCHSIZE_KIB) * 1024
end

--- Get the configured TLS verify mode for connecting to Exasol.
--- Configuration property: <code>tls_verify</code>.
--- Default value: <code>none</code>.
--- Available values: <code>none</code>, <code>peer</code>, <code>client_once</code>, <code>fail_if_no_peer_cert</code>.
--- See https://github.com/brunoos/luasec/wiki/LuaSec-1.1.0#sslnewcontextparams
--- @return string TLS verify mode
function ConnectionProperties:get_tls_verify() --
    return self.properties.tls_verify or "none"
end

--- Get the configured TLS protocol for connecting to Exasol.
--- Configuration property: <code>tls_protocol</code>.
--- Default value: <code>tlsv1_2</code>
--- Available values: <code>tlsv1</code>, <code>tlsv1_1</code>, <code>tlsv1_2</code>, <code>tlsv1_3</code>.
--- See https://github.com/brunoos/luasec/wiki/LuaSec-1.1.0#sslnewcontextparams
--- Run the following command to find out which TLS version your Exasol server supports:
--- openssl s_client -connect "<IP-Address>:<Port>" < /dev/null 2>/dev/null | grep Protocol
--- @return string TLS protocol
function ConnectionProperties:get_tls_protocol() --
    return self.properties.tls_protocol or "tlsv1_2"
end

--- Get the configured TLS options for connecting to Exasol.
--- The value is a comma separated list of options without spaces, e.g. <code>no_tlsv1,no_sslv2</code>.
--- Configuration property: <code>tls_options</code>.
--- Default value: <code>all</code>.
--- Available values: see output of <code>require("ssl").config.options</code>
--- @return string TLS options
function ConnectionProperties:get_tls_options() --
    return self.properties.tls_options or "all"
end

return ConnectionProperties
