-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")

local DEFAULT_FETCHSIZE_KIB<const> = 128

--- This internal class represents configuration properties for a database connection.
-- @classmod luasql.exasol.ConnectionProperties
local ConnectionProperties = {}

--- Available properties for the @{luasql.exasol.ConnectionProperties:create} method.
-- @table properties
--
-- @field fetchsize_kib The fetch size in KiB used when fetching query result data,
-- see @{luasql.exasol.ConnectionProperties:get_fetchsize_bytes}.
-- Default value: `128`.
--
-- @field tls_verify The TLS verify mode for connecting to Exasol,
--   see @{luasql.exasol.ConnectionProperties:get_tls_verify} and
-- [LuaSec documentation](https://github.com/brunoos/luasec/wiki/LuaSec-1.1.0#sslnewcontextparams).
-- Default value: `none`, available values:
--
-- * `none`
-- * `peer`
-- * `client_once`
-- * `fail_if_no_peer_cert`
--
-- @field tls_protocol The TLS protocol for connecting to Exasol,
--   see @{luasql.exasol.ConnectionProperties:get_tls_protocol} and
-- [LuaSec documentation](https://github.com/brunoos/luasec/wiki/LuaSec-1.1.0#sslnewcontextparams).
-- Default value: `tlsv1_2`, available values:
--
-- * `tlsv1`
-- * `tlsv1_1`
-- * `tlsv1_2`
-- * `tlsv1_3`
--
-- Run the following command to find out which TLS version your Exasol server supports:
--
-- `openssl s_client -connect "<IP-Address>:<Port>" < /dev/null 2>/dev/null | grep Protocol`
--
-- @field tls_options The TLS options for connecting to Exasol,
--   see @{luasql.exasol.ConnectionProperties:get_tls_options}.
-- The value is a comma-separated list of options without spaces, e.g. `no_tlsv1,no_sslv2`.
-- Default value: `all`. See output of the following Lua code for a list of available values:
--
-- `require("ssl").config.options`

--- Create a new instance of the Connection class.
-- @tparam ?table properties a properties object or `nil` to use default settings,
--   see @{luasql.exasol.ConnectionProperties:properties} for details
-- @treturn luasql.exasol.Connection connection the new instance
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
-- Configuration property: `fetchsize_kib`, see @{luasql.exasol.ConnectionProperties:properties}.
-- Default value: `131072` = `128 * 1024`.
-- @treturn integer fetchsize in bytes
function ConnectionProperties:get_fetchsize_bytes()
    return (self.properties.fetchsize_kib or DEFAULT_FETCHSIZE_KIB) * 1024
end

--- Get the configured TLS verify mode for connecting to Exasol.
-- Configuration property: `tls_verify`, see @{luasql.exasol.ConnectionProperties:properties}.
-- @treturn string TLS verify mode
function ConnectionProperties:get_tls_verify()
    return self.properties.tls_verify or "none"
end

--- Get the configured TLS protocol for connecting to Exasol.
-- Configuration property: `tls_protocol`, see @{luasql.exasol.ConnectionProperties:properties}.
-- @treturn string TLS protocol
function ConnectionProperties:get_tls_protocol()
    return self.properties.tls_protocol or "tlsv1_2"
end

--- Get the configured TLS options for connection to Exasol.
-- Configuration property: `tls_options`, see @{luasql.exasol.ConnectionProperties.properties}.
-- @treturn string TLS options
function ConnectionProperties:get_tls_options()
    return self.properties.tls_options or "all"
end

return ConnectionProperties
