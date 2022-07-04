--- This class provides methods for connecting to an Exasol database and closing all connections.
-- @classmod luasql.exasol.Environment
-- @field private exasol_websocket ExasolWebsocket
-- @field private connections table list of created connections
local Environment = {}

-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local connection = require("luasql.exasol.Connection")
local exaerror = require("exaerror")
local ConnectionProperties = require("luasql.exasol.ConnectionProperties")
local base64 = require("luasql.exasol.base64")

--- Load a Lua module like `require()` but with fallback to Exasol specific module names.
-- @tparam string modname the name of the module to load
-- @return any the loaded module
local function require_udf_module(modname)
    local success, result = pcall(require, modname)
    if success then
        return result
    else
        local alternative_modname = "_" .. modname
        log.warn("Loading module '%s' failed with error '%s', try loading '%s'", modname, result, alternative_modname)
        return require(alternative_modname)
    end
end

local pkey = require_udf_module("openssl.pkey")
local bignum = require_udf_module("openssl.bignum")

local WEBSOCKET_PROTOCOL = "wss"

local function load_exasol_websocket(args)
    if args and args.exasol_websocket then
        return args.exasol_websocket
    else
        return require("luasql.exasol.ExasolWebsocket")
    end
end

--- Create a new instance of the Environment class
-- @tparam ?table args allows injecting a websocket module. This is only useful in unit tests and
--   should be `nil` in production code.
-- @treturn luasql.exasol.Environment a new instance
function Environment:new(args)
    local object = {closed = false, connections = {}}
    object.exasol_websocket = load_exasol_websocket(args)
    self.__index = self
    setmetatable(object, self)
    return object
end

--- Encrypts a password using the given public key modulus and exponent.
-- @tparam string publicKeyModulus the hex encoded modulus of the public key
-- @tparam string publicKeyExponent the hex encoded exponent of the public key
-- @tparam string password the password to encrypt
-- @treturn string the encrypted password
local function encrypt_password(publicKeyModulus, publicKeyExponent, password)
    local rsa = pkey.new({type = "RSA", bits = 1024})
    local modulus = bignum.new("0x" .. publicKeyModulus)
    local exponent = bignum.new("0x" .. publicKeyExponent)
    rsa:setParameters({n = modulus, e = exponent})
    return base64.encode(rsa:encrypt(password))
end

--- Login to the database.
-- @tparam luasql.exasol.ExasolWebsocket socket the connection to the database
-- @tparam string username the username
-- @tparam string password the unencrypted password
-- @treturn table|nil connection metadata in case login was successful
-- @treturn table|nil `nil` if the operation was successful, otherwise the error that occured
local function login(socket, username, password)
    local response, err = socket:send_login_command()
    if err then
        return nil, err
    end
    local encrypted_password = encrypt_password(response.publicKeyModulus, response.publicKeyExponent, password)
    return socket:send_login_credentials(username, encrypted_password)
end

--- Connect to an Exasol database.
-- @tparam string sourcename hostname and port of the Exasol database, separated with a colon, e.g.:
--   `exasoldb.example.com:8563`. Note that the port is mandatory.
-- @tparam string username the username for logging in to the Exasol database
-- @tparam string password the password for logging in to the Exasol database
-- @tparam ?table properties optional connection properties, see @{luasql.exasol.ConnectionProperties:properties}
-- @treturn luasql.exasol.Connection|nil a new Connection or `nil` if the connection failed
-- @treturn table|nil `nil` if the operation was successful, otherwise the error that occured
-- @see ConnectionProperties:create
function Environment:connect(sourcename, username, password, properties)
    -- [impl -> dsn~luasql-environment-connect~0]
    if self.closed then
        exaerror.create("E-EDL-21", "Attempt to connect using an environment that is already closed"):raise(3)
    end
    local connection_properties = ConnectionProperties:create(properties)
    local socket = self.exasol_websocket.connect(WEBSOCKET_PROTOCOL .. "://" .. sourcename, connection_properties)
    local response, err = login(socket, username, password)
    if err then
        socket:close()
        if err["cause"] == "closed" then
            err = exaerror.create("E-EDL-19",
                                  "Login failed because socket is closed. Probably credentials are wrong: {{error}}",
                                  {error = tostring(err)})
        else
            err = exaerror.create("E-EDL-16", "Login failed: {{error}}", {error = tostring(err)})
        end
        err:add_mitigations("Check the credentials you provided.")
        return nil, err
    end
    log.trace("Connected to Exasol %s, maximum message size: %s bytes", response.releaseVersion,
              response.maxDataMessageSize)
    local session_id = response.sessionId
    local conn = connection:create(connection_properties, socket, session_id)
    self.connections[session_id] = conn
    return conn, nil
end

--- Closes the environment and all connections created using it.
-- @treturn boolean `true` if all connections where closed successfully
function Environment:close()
    -- [impl -> dsn~luasql-environment-close~0]
    if self.closed then
        log.warn(tostring(exaerror.create("W-EDL-20", "Attempted to close an already closed environment")))
        return false
    end

    log.trace("Closing environment: check if all %d connections are closed", #self.connections)
    for _, conn in pairs(self.connections) do
        if not conn.closed then
            log.warn(tostring(exaerror.create("W-EDL-38",
                                              "Cannot close environment because not all connections are closed")))
            return false
        end
    end
    self.closed = true
    return true
end

return Environment
