local connection = require("connection")
local websocket = require("websocket_connection")
local pkey = require("openssl.pkey")
local bignum = require("openssl.bignum")
local base64 = require("base64")
local log = require("remotelog")

local M = {}
function M:new()
    local object = {connections = {}}
    self.__index = self
    setmetatable(object, self)
    return object
end

local function encrypt_password(publicKeyModulus, publicKeyExponent, password)
    local rsa = pkey.new {type = "RSA", bits = 1024}
    local modulus = bignum.new("0x" .. publicKeyModulus)
    local exponent = bignum.new("0x" .. publicKeyExponent)
    rsa:setParameters({n = modulus, e = exponent})
    local encrypted_password = base64.encode(rsa:encrypt(password))
    return encrypted_password
end

local function login(socket, username, password)
    log.trace("Sending login command")
    local response = socket:send_json({command = "login", protocolVersion = 3})
    local encrypted_password = encrypt_password(response.publicKeyModulus,
                                                response.publicKeyExponent,
                                                password)
    log.trace("Login as user '%s'", username)
    return socket:send_json({
        username = username,
        password = encrypted_password,
        useCompression = false
    })
end

function M:connect(sourcename, username, password)
    local websocket_options = {receive_timeout = 3}
    local socket = websocket.connect("wss://" .. sourcename, websocket_options)
    local response = login(socket, username, password)
    log.trace("Connected to Exasol %s, maximum message size: %d bytes",
              response.releaseVersion, response.maxDataMessageSize)
    local session_id = response.sessionId
    local conn = connection:create(socket, session_id)
    self.connections[session_id] = conn
    return conn
end

function M:close()
    log.trace("Closing environment: close all %d connections", #self.connections)
    for _, conn in pairs(self.connections) do conn:close() end
end

return M
