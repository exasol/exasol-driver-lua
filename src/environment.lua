local connection = require("connection")
local websocket = require("exasol_websocket")
local pkey = require("openssl.pkey")
local bignum = require("openssl.bignum")
local base64 = require("base64")
-- [impl->dsn~logging-with-remotelog~1]
local log = require("remotelog")
local exaerror = require("exaerror")

local WEBSOCKET_PROTOCOL = "wss"

local M = {}
function M:new()
    local object = {connections = {}}
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
    log.trace("Sending login command")
    local response = socket:send_login_command()
    local encrypted_password = encrypt_password(response.publicKeyModulus, response.publicKeyExponent, password)
    log.trace("Login as user '%s'", username)
    return socket:send_login_credentials(username, encrypted_password)
end

-- [impl -> dsn~luasql-environment-connect~0]
function M:connect(sourcename, username, password)
    local socket = websocket.connect(WEBSOCKET_PROTOCOL .. "://" .. sourcename)
    local response, err = login(socket, username, password)
    if err then
        if err.cause == "closed" then
            err = exaerror.create("E-EDL-19",
                                  "Login failed because socket is closed. Probably credentials are wrong: {{error}}",
                                  {error = tostring(err)})
        else
            err = exaerror.create("E-EDL-16", "Login failed: {{error}}", {error = tostring(err)})
        end
        err:add_mitigations("Check the credentials you provided.")
        log.warn("%s", err)
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
    log.trace("Closing environment: close all %d connections", #self.connections)
    for _, conn in pairs(self.connections) do conn:close() end
end

return M
