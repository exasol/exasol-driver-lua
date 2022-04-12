local connection = require("connection")
local pkey = require("openssl.pkey")
local bignum = require("openssl.bignum")
local base64 = require("base64")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")

local WEBSOCKET_PROTOCOL = "wss"

local function load_exasol_websocket(args)
    if args and args.exasol_websocket then
        return args.exasol_websocket
    else
        return require("exasol_websocket")
    end
end

--- This class provides methods for connecting to an Exasol database and closing all connections.
--- @class Environment
--- @field private exasol_websocket ExasolWebsocket
--- @field private connections table list of created connections
local Environment = {}

--- Create a new instance of the Environment class
--- @param args table|nil allows injecting a websocket module. This is only useful in unit tests and
---   should be nil in production code.
--- @return Environment environment a new instance
function Environment:new(args)
    local object = {closed = false, connections = {}}
    object.exasol_websocket = load_exasol_websocket(args)
    self.__index = self
    setmetatable(object, self)
    return object
end

--- Encrypts a password using the given public key modulus and exponent.
--- @param publicKeyModulus string the hex encoded modulus of the public key
--- @param publicKeyExponent string the hex encoded exponent of the public key
--- @param password string the password to encrypt
--- @return string encrypted_password the encrypted password
local function encrypt_password(publicKeyModulus, publicKeyExponent, password)
    local rsa = pkey.new({type = "RSA", bits = 1024})
    local modulus = bignum.new("0x" .. publicKeyModulus)
    local exponent = bignum.new("0x" .. publicKeyExponent)
    rsa:setParameters({n = modulus, e = exponent})
    return base64.encode(rsa:encrypt(password))
end

--- Login to the database.
--- See https://github.com/exasol/websocket-api/blob/master/docs/commands/loginV3.md
---@param socket ExasolWebsocket the connection to the database
---@param username string the username
---@param password string the password
---@return table|nil response_data connection metadata in case login was successful
---@return nil|table|string err an error if login failed
local function login(socket, username, password)
    local response, err = socket:send_login_command()
    if err then return nil, err end
    local encrypted_password = encrypt_password(response.publicKeyModulus, response.publicKeyExponent, password)
    return socket:send_login_credentials(username, encrypted_password)
end

--- Connect to an Exasol database.
--- @param sourcename string hostname and port of the Exasol database, separated with a colon, e.g.:
--- <code>exasoldb.example.com:8563</code>. Note that the port is mandatory.
--- @param username string the username for logging in to the Exasol database
--- @param password string the password for logging in to the Exasol database
--- @return Connection|nil connection a new Connection or nil if the connection failed
--- @return nil|table|string err an error or nil if the connection was successful
--- [impl -> dsn~luasql-environment-connect~0]
function Environment:connect(sourcename, username, password)
    if self.closed then
        exaerror.create("E-EDL-21", "Attempt to connect using an environment that is already closed"):raise(3)
    end
    local socket = self.exasol_websocket.connect(WEBSOCKET_PROTOCOL .. "://" .. sourcename)
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
    log.trace("Connected to Exasol %s, maximum message size: %d bytes", response.releaseVersion,
              response.maxDataMessageSize)
    local session_id = response.sessionId
    local conn = connection:create(socket, session_id)
    self.connections[session_id] = conn
    return conn, nil
end

--- Closes the environment and all connections created using it.
--- @return boolean success true if all connections where closed successfully
--- [impl -> dsn~luasql-environment-close~0]
function Environment:close()
    if self.closed then
        log.warn(tostring(exaerror.create("E-EDL-20", "Attempted to close an already closed environment")))
        return true
    end

    log.trace("Closing environment: close all %d connections", #self.connections)
    for _, conn in pairs(self.connections) do conn:close() end
    self.closed = true
    return true
end

return Environment
