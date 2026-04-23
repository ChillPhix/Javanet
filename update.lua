-- update.lua
-- Javanet System-Wide Updater
-- Run on ANY Javanet computer to update its files from GitHub.
-- Run on mainframe with "broadcast" arg to tell all terminals to update too.
--
-- Usage:
--   /jnet/update.lua              -- update this computer only
--   /jnet/update.lua broadcast    -- update this + tell all terminals to update
--   /jnet/update.lua listen       -- (internal) wait for update signal then update

local args = { ... }
local mode = args[1] or "self"

local REPO = "https://raw.githubusercontent.com/ChillPhix/Javanet/main/"
local UPDATE_PROTOCOL = "JNET_UPDATE"

-- ============================================================
-- File list (everything except configs and data)
-- ============================================================

local ALL_FILES = {
    -- Core libs
    "lib/jnet_proto.lua",
    "lib/jnet_ui.lua",
    "lib/jnet_anim.lua",
    "lib/jnet_config.lua",
    "lib/jnet_monitor.lua",
    "lib/jnet_gpu.lua",
    "lib/jnet_puzzle.lua",
    "lib/jnet_modules.lua",
    -- Runtime
    "runtime/terminal.lua",
    -- Customizer
    "customizer/customizer.lua",
    -- Updater (self-update)
    "update.lua",
    -- Network modules
    "modules/network/card_reader.lua",
    "modules/network/door_lock.lua",
    "modules/network/card_issuer.lua",
    "modules/network/status_panel.lua",
    "modules/network/zone_panel.lua",
    "modules/network/breach_panel.lua",
    "modules/network/personnel_panel.lua",
    "modules/network/log_panel.lua",
    "modules/network/full_log.lua",
    "modules/network/clock.lua",
    "modules/network/lockdown_control.lua",
    "modules/network/breach_control.lua",
    "modules/network/entity_control.lua",
    "modules/network/entity_display.lua",
    "modules/network/entity_procedures.lua",
    "modules/network/facility_state.lua",
    "modules/network/panic_button.lua",
    "modules/network/siren.lua",
    "modules/network/player_detector.lua",
    "modules/network/archive_browser.lua",
    "modules/network/mail_client.lua",
    "modules/network/radio.lua",
    "modules/network/remote_door.lua",
    "modules/network/personnel_lookup.lua",
    "modules/network/admin_panel.lua",
    "modules/network/approval_queue.lua",
    -- Offense modules
    "modules/offense/scanner.lua",
    "modules/offense/cracker.lua",
    "modules/offense/interceptor.lua",
    "modules/offense/replayer.lua",
    "modules/offense/card_spoofer.lua",
    "modules/offense/payload_deployer.lua",
    "modules/offense/worm_commander.lua",
    "modules/offense/agent_control.lua",
    "modules/offense/keylogger.lua",
    "modules/offense/hmac_cracker.lua",
    "modules/offense/signal_jammer.lua",
    -- Defense modules
    "modules/defense/firewall.lua",
    "modules/defense/ids.lua",
    "modules/defense/deep_scan.lua",
    "modules/defense/tracer.lua",
    "modules/defense/counter_hack.lua",
    "modules/defense/antivirus.lua",
    "modules/defense/integrity_check.lua",
    "modules/defense/honeypot.lua",
    "modules/defense/quarantine.lua",
    "modules/defense/sentinel.lua",
    -- Payloads
    "payloads/lockout.lua",
    "payloads/worm.lua",
    "payloads/backdoor.lua",
    "payloads/agent.lua",
    -- Mainframe
    "mainframe/mainframe.lua",
    "mainframe/db.lua",
}

-- ============================================================
-- Update this computer's files
-- ============================================================

local function updateSelf()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.clear()
    term.setCursorPos(1, 1)

    print("================================")
    print("  JAVANET UPDATER")
    print("================================")
    print("")

    -- Ensure directories exist
    local dirs = {
        "/jnet/lib", "/jnet/modules", "/jnet/modules/network",
        "/jnet/modules/offense", "/jnet/modules/defense",
        "/jnet/runtime", "/jnet/customizer", "/jnet/mainframe", "/jnet/payloads",
    }
    for _, dir in ipairs(dirs) do
        if not fs.exists(dir) then fs.makeDir(dir) end
    end

    local updated = 0
    local failed = 0
    local total = #ALL_FILES

    for i, file in ipairs(ALL_FILES) do
        local dest = "/jnet/" .. file
        local url = REPO .. file

        -- Progress
        local pct = math.floor(i / total * 100)
        term.setCursorPos(1, 6)
        term.setTextColor(colors.white)
        term.clearLine()
        term.write("Updating: " .. file)
        term.setCursorPos(1, 7)
        term.clearLine()

        -- Progress bar
        local barW = 30
        local filled = math.floor(barW * pct / 100)
        term.setTextColor(colors.lime)
        term.write("[" .. string.rep("=", filled) .. string.rep(" ", barW - filled) .. "] " .. pct .. "%")

        -- Download
        local ok, response = pcall(http.get, url)
        if ok and response then
            local content = response.readAll()
            response.close()

            -- Ensure parent directory exists
            local dir = fs.getDir(dest)
            if not fs.exists(dir) then fs.makeDir(dir) end

            -- Delete old file if exists
            if fs.exists(dest) then fs.delete(dest) end

            local f = fs.open(dest, "w")
            f.write(content)
            f.close()
            updated = updated + 1
        else
            failed = failed + 1
            term.setCursorPos(1, 8)
            term.setTextColor(colors.orange)
            term.clearLine()
            term.write("  SKIP: " .. file)
        end
    end

    -- Summary
    term.setCursorPos(1, 10)
    term.setTextColor(colors.lime)
    print("Update complete!")
    term.setTextColor(colors.white)
    print("  Updated: " .. updated .. "/" .. total)
    if failed > 0 then
        term.setTextColor(colors.orange)
        print("  Failed:  " .. failed)
    end
    print("")

    return updated, failed
end

-- ============================================================
-- Broadcast update signal to all terminals
-- ============================================================

local function broadcastUpdate()
    -- Open all modems
    local modems = { peripheral.find("modem") }
    for _, modem in ipairs(modems) do
        local name = peripheral.getName(modem)
        if not rednet.isOpen(name) then rednet.open(name) end
    end

    term.setTextColor(colors.yellow)
    print("Broadcasting update signal...")
    print("All terminals will update and reboot.")
    print("")

    -- Send update command on both protocols so everyone hears it
    rednet.broadcast({ type = "system_update", repo = REPO, ts = os.epoch("utc") }, "JNET")
    rednet.broadcast({ type = "system_update", repo = REPO, ts = os.epoch("utc") }, "JNET_UPDATE")

    term.setTextColor(colors.lime)
    print("Update signal sent!")
    print("")
    term.setTextColor(colors.white)
    print("This computer will now update itself")
    print("and reboot in 5 seconds.")
    sleep(2)
end

-- ============================================================
-- Listen mode: wait for update signal, then update and reboot
-- Called by the runtime on receiving an update message
-- ============================================================

local function listenForUpdate()
    -- Open all modems
    local modems = { peripheral.find("modem") }
    for _, modem in ipairs(modems) do
        local name = peripheral.getName(modem)
        if not rednet.isOpen(name) then rednet.open(name) end
    end

    while true do
        local senderId, msg, protocol = rednet.receive(nil, 1)
        if msg and type(msg) == "table" and msg.type == "system_update" then
            -- Got update signal
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.yellow)
            term.clear()
            term.setCursorPos(1, 1)
            print("SYSTEM UPDATE RECEIVED")
            print("Updating from mainframe signal...")
            print("")
            sleep(1)

            updateSelf()

            term.setTextColor(colors.yellow)
            print("")
            print("Rebooting in 3 seconds...")
            sleep(3)
            os.reboot()
            return
        end
    end
end

-- ============================================================
-- Main
-- ============================================================

if mode == "broadcast" then
    -- Update self + tell everyone else to update
    broadcastUpdate()
    updateSelf()
    term.setTextColor(colors.yellow)
    print("")
    print("Rebooting in 3 seconds...")
    sleep(3)
    os.reboot()

elseif mode == "listen" then
    -- Wait for update signal
    listenForUpdate()

else
    -- Just update this computer
    updateSelf()
    term.setTextColor(colors.white)
    print("")
    print("Reboot to apply changes? [Y/N]")
    while true do
        local ev = {os.pullEvent()}
        if ev[1] == "key" then
            if ev[2] == keys.y then os.reboot() end
            if ev[2] == keys.n then break end
        elseif ev[1] == "char" then
            if ev[2] == "y" or ev[2] == "Y" then os.reboot() end
            if ev[2] == "n" or ev[2] == "N" then break end
        elseif ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            os.reboot()
        end
    end
end
