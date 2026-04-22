-- lockout.lua — Payload
-- Visual takeover screen showing attacker faction branding.
-- Deployed via payload_deployer after successful crack.

local ui = require("lib.jnet_ui")
local anim = require("lib.jnet_anim")
local config = require("lib.jnet_config")

local args = {...}
local attackerName = args[1] or "UNKNOWN"
local attackerMotto = args[2] or "Your network belongs to us."
local attackerFg = args[3] or "red"
local attackerBg = args[4] or "black"

-- Load attacker logo if provided
local logoLines = nil
if fs.exists("/.attacker_logo.txt") then
    local f = fs.open("/.attacker_logo.txt", "r")
    logoLines = {}
    for line in f.readAll():gmatch("[^\n]+") do logoLines[#logoLines+1] = line end
    f.close()
end

-- Apply attacker colors
ui.applyColors(attackerFg, attackerBg)

-- Run lockout reveal animation
anim.lockoutReveal(attackerName, attackerMotto, logoLines, ui.FG, ui.BG)

local W, H = ui.getSize()
-- Lockout message
ui.centerWrite(H - 4, "THIS TERMINAL HAS BEEN SEIZED", ui.ERR, ui.BG)
ui.centerWrite(H - 3, "All systems are under our control.", ui.DIM, ui.BG)
ui.centerWrite(H - 1, "[ LOCKED ]", ui.ERR, ui.BG)

-- Trap: prevent normal exit. Only Ctrl+T terminate can break out.
while true do
    local ev = os.pullEventRaw()
    if ev == "terminate" then
        -- Even on terminate, show one more taunt
        ui.clear()
        ui.centerWrite(math.floor(H/2), "Nice try.", ui.ERR, ui.BG)
        sleep(2)
        break
    end
end
