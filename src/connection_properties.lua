-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")

local DEFAULT_FETCHSIZE_KIB<const> = 128

--- This class represents configuration properties for a database connection.
-- @classmod ConnectionProperties
-- @field private properties table the properties
local ConnectionProperties = {}

--- Create a new instance of the Connection class.
-- @param properties table|nil a properties object or `nil` to use default settings
-- @return Connection connection the new instance
-- @raise error if given properties are not valid
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
-- Configuration property: `fetchsize_kib`.
-- Default value: `131072` = `128 * 1024`.
-- @return number fetchsize in bytes
function ConnectionProperties:get_fetchsize_bytes() --
    return (self.properties.fetchsize_kib or DEFAULT_FETCHSIZE_KIB) * 1024
end

--- Get the configured TLS verify mode for connecting to Exasol.
-- Configuration property: `tls_verify`.
-- Default value: `none`.
-- Available values: `none`, `peer`, `client_once`, `fail_if_no_peer_cert`.
-- See [LuaSec documentation](https://github.com/brunoos/luasec/wiki/LuaSec-1.1.0#sslnewcontextparams).
-- @return string TLS verify mode
function ConnectionProperties:get_tls_verify() --
    return self.properties.tls_verify or "none"
end

--- Get the configured TLS protocol for connecting to Exasol.
--
-- * Configuration property: `tls_protocol`.
-- * Default value: `tlsv1_2`
-- * Available values:
--     * `tlsv1`
--     * `tlsv1_1`
--     * `tlsv1_2`
--     * `tlsv1_3`
-- 
-- See [LuaSec documentation](https://github.com/brunoos/luasec/wiki/LuaSec-1.1.0#sslnewcontextparams).
-- Run the following command to find out which TLS version your Exasol server supports:
-- 
-- `openssl s_client -connect "<IP-Address>:<Port>" < /dev/null 2>/dev/null | grep Protocol`
-- @return string TLS protocol
function ConnectionProperties:get_tls_protocol() --
    return self.properties.tls_protocol or "tlsv1_2"
end

--- Get the configured TLS options for connecting to Exasol.
-- The value is a comma separated list of options without spaces, e.g. `no_tlsv1,no_sslv2`.
--
-- * Configuration property: `tls_options`.
-- * Default value: `all`.
-- * Available values: see output of
-- 
-- `require("ssl").config.options`
-- @return string TLS options
function ConnectionProperties:get_tls_options() --
    return self.properties.tls_options or "all"
end

return ConnectionProperties
