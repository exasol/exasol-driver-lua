local connection = require("connection")
local websocket = require("websocket_connection")
local pkey = require("openssl.pkey")
local bignum = require("openssl.bignum")
local base64 = require("base64")

local M = {}
function M:new(object)
    object = object or {}
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
    local response = socket:sendJson({command = "login", protocolVersion = 3})
    local encrypted_password = encrypt_password(response.publicKeyModulus,
                                                response.publicKeyExponent,
                                                password)
    return socket:sendJson({
        username = username,
        password = encrypted_password,
        useCompression = false
    })
end

function M:connect(sourcename, username, password)
    print("Connecting to", sourcename, username, password)
    local websocketOptions = {receive_timeout = 3}
    local socket = websocket.connect("wss://" .. sourcename, websocketOptions)
    local loginResponse = login(socket, username, password)
    local details = {
        sessionId = loginResponse.sessionId,
        maxDataMessageSize = loginResponse.maxDataMessageSize,
        dbVersion = loginResponse.releaseVersion
    }
    local conn = connection:new(socket, details)
    print("Connection started with session id", details.sessionId)
    return conn
end

function M:close() print("Closing environment") end

return M
