-- jnet_proto.lua
-- Module cache: return existing instance if already loaded
if _JNET_LOADED and _JNET_LOADED["jnet_proto"] then return _JNET_LOADED["jnet_proto"] end
if not _JNET_LOADED then _JNET_LOADED = {} end
-- HMAC-SHA256 signed rednet protocol for Javanet
-- Provides authenticated, replay-protected messaging between faction computers.
-- Place at /lib/jnet_proto.lua on every Javanet computer.

local M = {}

M.SECRET_PATH = "/.jnet_secret"
M.PROTOCOL = "JNET"
M.ATK_PROTOCOL = "JNET_ATK"
M.NONCE_EXPIRY = 10
M.MAX_NONCES = 2000

-- ============================================================
-- SHA-256 Implementation (pure Lua for CC:T)
-- ============================================================

local band, bor, bxor, bnot, rshift, lshift
if bit32 then
    band, bor, bxor, bnot, rshift, lshift =
        bit32.band, bit32.bor, bit32.bxor, bit32.bnot, bit32.rshift, bit32.lshift
elseif bit then
    band, bor, bxor, bnot, rshift, lshift =
        bit.band, bit.bor, bit.bxor, bit.bnot, bit.brshift, bit.blshift
end

local function rrot(x, n) return bor(rshift(x, n), lshift(band(x, 0xFFFFFFFF), 32 - n)) end

local K = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}

local function preprocess(msg)
    local len = #msg
    local bits = len * 8
    msg = msg .. "\x80"
    while (#msg % 64) ~= 56 do msg = msg .. "\0" end
    msg = msg .. string.char(
        0, 0, 0, 0,
        band(rshift(bits, 24), 0xFF),
        band(rshift(bits, 16), 0xFF),
        band(rshift(bits, 8), 0xFF),
        band(bits, 0xFF)
    )
    return msg
end

function M.sha256(msg)
    msg = preprocess(msg)
    local h0,h1,h2,h3,h4,h5,h6,h7 =
        0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
        0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19

    for i = 1, #msg, 64 do
        local w = {}
        for j = 1, 16 do
            local b = (i - 1) + (j - 1) * 4
            w[j] = bor(
                lshift(msg:byte(b+1), 24),
                lshift(msg:byte(b+2), 16),
                lshift(msg:byte(b+3), 8),
                msg:byte(b+4)
            )
        end
        for j = 17, 64 do
            local s0 = bxor(rrot(w[j-15], 7), rrot(w[j-15], 18), rshift(w[j-15], 3))
            local s1 = bxor(rrot(w[j-2], 17), rrot(w[j-2], 19), rshift(w[j-2], 10))
            w[j] = band(w[j-16] + s0 + w[j-7] + s1, 0xFFFFFFFF)
        end

        local a,b,c,d,e,f,g,h = h0,h1,h2,h3,h4,h5,h6,h7
        for j = 1, 64 do
            local S1 = bxor(rrot(e, 6), rrot(e, 11), rrot(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local t1 = band(h + S1 + ch + K[j] + w[j], 0xFFFFFFFF)
            local S0 = bxor(rrot(a, 2), rrot(a, 13), rrot(a, 22))
            local maj = bxor(band(a, b), band(a, c), band(b, c))
            local t2 = band(S0 + maj, 0xFFFFFFFF)
            h = g; g = f; f = e; e = band(d + t1, 0xFFFFFFFF)
            d = c; c = b; b = a; a = band(t1 + t2, 0xFFFFFFFF)
        end
        h0 = band(h0+a,0xFFFFFFFF); h1 = band(h1+b,0xFFFFFFFF)
        h2 = band(h2+c,0xFFFFFFFF); h3 = band(h3+d,0xFFFFFFFF)
        h4 = band(h4+e,0xFFFFFFFF); h5 = band(h5+f,0xFFFFFFFF)
        h6 = band(h6+g,0xFFFFFFFF); h7 = band(h7+h,0xFFFFFFFF)
    end

    return string.format("%08x%08x%08x%08x%08x%08x%08x%08x",h0,h1,h2,h3,h4,h5,h6,h7)
end

-- ============================================================
-- HMAC-SHA256
-- ============================================================

function M.hmac(key, msg)
    if #key > 64 then
        local h = M.sha256(key)
        key = ""
        for i = 1, #h, 2 do key = key .. string.char(tonumber(h:sub(i,i+1), 16)) end
    end
    key = key .. string.rep("\0", 64 - #key)
    local o_pad, i_pad = "", ""
    for i = 1, 64 do
        o_pad = o_pad .. string.char(bxor(key:byte(i), 0x5C))
        i_pad = i_pad .. string.char(bxor(key:byte(i), 0x36))
    end
    return M.sha256(o_pad .. M.sha256(i_pad .. msg))
end

-- ============================================================
-- Canonical Serialization (deterministic key ordering)
-- ============================================================

local function canonicalize(val)
    local t = type(val)
    if t == "string" then return string.format("%q", val)
    elseif t == "number" then return tostring(val)
    elseif t == "boolean" then return tostring(val)
    elseif t == "nil" then return "nil"
    elseif t == "table" then
        local keys = {}
        for k in pairs(val) do keys[#keys+1] = k end
        table.sort(keys, function(a,b)
            if type(a) ~= type(b) then return type(a) < type(b) end
            return tostring(a) < tostring(b)
        end)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts+1] = "[" .. canonicalize(k) .. "]=" .. canonicalize(val[k])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return tostring(val)
end

-- ============================================================
-- Secret Management
-- ============================================================

local cachedSecret = nil

function M.loadSecret()
    if cachedSecret then return cachedSecret end
    if not fs.exists(M.SECRET_PATH) then return nil end
    local f = fs.open(M.SECRET_PATH, "r")
    local s = f.readAll():gsub("^%s+",""):gsub("%s+$","")
    f.close()
    if #s > 0 then cachedSecret = s end
    return cachedSecret
end

function M.clearSecretCache()
    cachedSecret = nil
end

-- ============================================================
-- Nonce Deduplication
-- ============================================================

local seenNonces = {}
local nonceCount = 0

local function recordNonce(nonce, ts)
    seenNonces[nonce] = ts
    nonceCount = nonceCount + 1
    if nonceCount > M.MAX_NONCES then
        local now = os.epoch("utc") / 1000
        local newSeen = {}
        local newCount = 0
        for n, t in pairs(seenNonces) do
            if now - t < M.NONCE_EXPIRY * 2 then
                newSeen[n] = t
                newCount = newCount + 1
            end
        end
        seenNonces = newSeen
        nonceCount = newCount
    end
end

-- ============================================================
-- Modem Management
-- ============================================================

function M.openModem()
    local modem = peripheral.find("modem")
    if not modem then return false, "No modem found" end
    local name = peripheral.getName(modem)
    if not rednet.isOpen(name) then rednet.open(name) end
    return true, name
end

function M.findRawModem()
    local modem = peripheral.find("modem")
    if not modem then return nil end
    return modem, peripheral.getName(modem)
end

-- ============================================================
-- Signed Messaging (Internal Protocol)
-- ============================================================

function M.send(targetId, msgType, payload)
    local secret = M.loadSecret()
    if not secret then return false, "No secret" end
    local ts = os.epoch("utc") / 1000
    local nonce = string.format("%08x%08x", math.random(0, 0xFFFFFFFF), math.random(0, 0xFFFFFFFF))
    local body = { type = msgType, payload = payload, ts = ts, nonce = nonce, sender = os.getComputerID() }
    local sig = M.hmac(secret, canonicalize(body))
    body.sig = sig
    rednet.send(targetId, body, M.PROTOCOL)
    return true
end

function M.broadcast(msgType, payload)
    local secret = M.loadSecret()
    if not secret then return false, "No secret" end
    local ts = os.epoch("utc") / 1000
    local nonce = string.format("%08x%08x", math.random(0, 0xFFFFFFFF), math.random(0, 0xFFFFFFFF))
    local body = { type = msgType, payload = payload, ts = ts, nonce = nonce, sender = os.getComputerID() }
    local sig = M.hmac(secret, canonicalize(body))
    body.sig = sig
    rednet.broadcast(body, M.PROTOCOL)
    return true
end

function M.receive(timeout)
    local senderId, msg = rednet.receive(M.PROTOCOL, timeout)
    if not senderId then return nil end
    if type(msg) ~= "table" or not msg.type or not msg.sig or not msg.ts or not msg.nonce then
        return nil, "malformed"
    end
    local secret = M.loadSecret()
    if not secret then return nil, "no_secret" end
    local now = os.epoch("utc") / 1000
    if math.abs(now - msg.ts) > M.NONCE_EXPIRY then return nil, "stale" end
    if seenNonces[msg.nonce] then return nil, "replay" end
    local sig = msg.sig
    msg.sig = nil
    local expected = M.hmac(secret, canonicalize(msg))
    msg.sig = sig
    if sig ~= expected then return nil, "bad_sig" end
    recordNonce(msg.nonce, msg.ts)
    return senderId, msg
end

function M.request(targetId, msgType, payload, timeout)
    timeout = timeout or 5
    local ok, err = M.send(targetId, msgType, payload)
    if not ok then return nil, err end
    local deadline = os.epoch("utc") / 1000 + timeout
    while true do
        local remaining = deadline - os.epoch("utc") / 1000
        if remaining <= 0 then return nil, "timeout" end
        local sid, msg = M.receive(remaining)
        if sid == targetId and msg then return msg end
    end
end

-- ============================================================
-- Attack Protocol (unsigned, cross-faction)
-- ============================================================

function M.sendAtk(targetId, msgType, payload)
    local body = { type = msgType, payload = payload, ts = os.epoch("utc") / 1000, sender = os.getComputerID() }
    rednet.send(targetId, body, M.ATK_PROTOCOL)
    return true
end

function M.receiveAtk(timeout)
    local senderId, msg = rednet.receive(M.ATK_PROTOCOL, timeout)
    if not senderId then return nil end
    if type(msg) ~= "table" or not msg.type then return nil, "malformed" end
    return senderId, msg
end

function M.requestAtk(targetId, msgType, payload, timeout)
    timeout = timeout or 10
    M.sendAtk(targetId, msgType, payload)
    local deadline = os.epoch("utc") / 1000 + timeout
    while true do
        local remaining = deadline - os.epoch("utc") / 1000
        if remaining <= 0 then return nil, "timeout" end
        local sid, msg = M.receiveAtk(remaining)
        if sid == targetId and msg then return msg end
    end
end

-- ============================================================
-- Stealth Protocol (raw modem, no rednet)
-- ============================================================

function M.stealthSend(modem, channel, msgType, payload)
    local body = { type = msgType, payload = payload, ts = os.epoch("utc") / 1000, sender = os.getComputerID() }
    modem.transmit(channel, channel, body)
    return true
end

function M.stealthListen(modem, channel)
    if not modem.isOpen(channel) then modem.open(channel) end
end

function M.stealthClose(modem, channel)
    if modem.isOpen(channel) then modem.close(channel) end
end

-- ============================================================
-- Inline Message Verification
-- For use when the event is already consumed from os.pullEvent
-- ============================================================

function M.verifyMessage(msg)
    if type(msg) ~= "table" then return false, "not_table" end
    if not msg.type or not msg.sig or not msg.ts or not msg.nonce then return false, "malformed" end
    local secret = M.loadSecret()
    if not secret then return false, "no_secret" end
    local now = os.epoch("utc") / 1000
    if math.abs(now - msg.ts) > M.NONCE_EXPIRY then return false, "stale" end
    if seenNonces[msg.nonce] then return false, "replay" end
    local sig = msg.sig
    msg.sig = nil
    local expected = M.hmac(secret, canonicalize(msg))
    msg.sig = sig
    if sig ~= expected then return false, "bad_sig" end
    recordNonce(msg.nonce, msg.ts)
    return true
end

_JNET_LOADED["jnet_proto"] = M
return M
