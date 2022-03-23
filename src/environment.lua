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

local M = {}
function M:new(args)
    local object = {closed = false, connections = {}}
    object.exasol_websocket = load_exasol_websocket(args)
    self.__index = self
    setmetatable(object, self)
    return object
end

local function encrypt_password(publicKeyModulus, publicKeyExponent, password)
    local rsa = pkey.new({type = "RSA", bits = 1024})
    local modulus = bignum.new("0x" .. publicKeyModulus)
    local exponent = bignum.new("0x" .. publicKeyExponent)
    rsa:setParameters({n = modulus, e = exponent})
    local encrypted_password = base64.encode(rsa:encrypt(password))
    return encrypted_password
end

local function login(socket, username, password)
    local response, err = socket:send_login_command()
    if err then return nil, err end
    local encrypted_password = encrypt_password(response.publicKeyModulus, response.publicKeyExponent, password)
    return socket:send_login_credentials(username, encrypted_password)
end

-- [impl -> dsn~luasql-environment-connect~0]
function M:connect(sourcename, username, password)
    if self.closed then
        exaerror.create("E-EDL-21", "Attempt to connect using an environment that is already closed"):raise(3)
    end
    local socket = self.exasol_websocket.connect(WEBSOCKET_PROTOCOL .. "://" .. sourcename)
    local response, err = login(socket, username, password)
    if err then
        socket:close()
        if err.cause == "closed" then
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

-- [impl -> dsn~luasql-environment-close~0]
function M:close()
    if self.closed then
        log.warn(tostring(exaerror.create("E-EDL-20", "Attempted to close an already closed environment")))
        return
    end

    log.trace("Closing environment: close all %d connections", #self.connections)
    for _, conn in pairs(self.connections) do conn:close() end
    self.closed = true
end

return M
