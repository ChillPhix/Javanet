-- install.lua
-- Javanet Universal Installer & Updater
-- Usage:
--   wget run <url>/install.lua              -- install as terminal
--   wget run <url>/install.lua mainframe    -- install as mainframe
--   wget run <url>/install.lua update       -- update existing install
--   wget run <url>/install.lua broadcast    -- update all network computers

local args = {...}
local mode = args[1] or "terminal"

local REPO = "https://raw.githubusercontent.com/ChillPhix/Javanet/main/"

-- ============================================================
-- File Lists
-- ============================================================

local CORE_FILES = {
    "lib/jnet_proto.lua",
    "lib/jnet_ui.lua",
    "lib/jnet_anim.lua",
    "lib/jnet_config.lua",
    "lib/jnet_monitor.lua",
    "lib/jnet_gpu.lua",
    "lib/jnet_puzzle.lua",
    "lib/jnet_modules.lua",
    "runtime/terminal.lua",
    "customizer/customizer.lua",
    "update.lua",
}

local NETWORK_MODULES = {
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
}

local OFFENSE_MODULES = {
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
}

local DEFENSE_MODULES = {
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
}

local PAYLOADS = {
    "payloads/lockout.lua",
    "payloads/worm.lua",
    "payloads/backdoor.lua",
    "payloads/agent.lua",
}

local MAINFRAME_FILES = {
    "mainframe/mainframe.lua",
    "mainframe/db.lua",
}

-- ============================================================
-- Helpers
-- ============================================================

local function genSecret()
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local s = ""
    for i = 1, 32 do
        local c = math.random(#chars)
        s = s .. chars:sub(c, c)
    end
    return s
end

local function download(file)
    local dest = "/jnet/" .. file
    local dir = fs.getDir(dest)
    if not fs.exists(dir) then fs.makeDir(dir) end
    if fs.exists(dest) then fs.delete(dest) end

    local url = REPO .. file
    local ok, response = pcall(http.get, url)
    if ok and response then
        local content = response.readAll()
        response.close()
        local f = fs.open(dest, "w")
        f.write(content)
        f.close()
        return true
    end
    return false
end

-- ============================================================
-- Broadcast Update (tell all terminals to re-install)
-- ============================================================

if mode == "broadcast" then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.clear()
    term.setCursorPos(1, 1)

    print("================================")
    print("  JAVANET NETWORK UPDATE")
    print("================================")
    print("")

    -- Open all modems
    local modems = { peripheral.find("modem") }
    if #modems == 0 then
        term.setTextColor(colors.red)
        print("No modem found!")
        return
    end
    for _, modem in ipairs(modems) do
        local name = peripheral.getName(modem)
        if not rednet.isOpen(name) then rednet.open(name) end
    end

    term.setTextColor(colors.white)
    print("Broadcasting update signal to")
    print("all terminals on the network...")
    print("")

    -- Broadcast on multiple protocols so everyone hears it
    local updateMsg = { type = "system_update", repo = REPO, ts = os.epoch("utc") }
    rednet.broadcast(updateMsg, "JNET")
    rednet.broadcast(updateMsg, "JNET_UPDATE")
    rednet.broadcast(updateMsg, "JNET_ATK")

    term.setTextColor(colors.lime)
    print("Signal sent!")
    print("")
    term.setTextColor(colors.white)
    print("Now updating this computer...")
    print("")
    sleep(1)

    -- Fall through to update self
    mode = "update"
end

-- ============================================================
-- Main Installer / Updater
-- ============================================================

local isUpdate = (mode == "update" or mode == "listen")
local isMainframe = (mode == "mainframe")

term.setBackgroundColor(colors.black)
term.setTextColor(colors.yellow)
term.clear()
term.setCursorPos(1, 1)

if isUpdate then
    print("================================")
    print("  JAVANET UPDATER")
    print("================================")
else
    print("================================")
    print("  JAVANET INSTALLER")
    print("  Mode: " .. mode)
    print("================================")
end
print("")

-- Create directories
local dirs = {
    "/jnet", "/jnet/lib", "/jnet/modules",
    "/jnet/modules/network", "/jnet/modules/offense", "/jnet/modules/defense",
    "/jnet/runtime", "/jnet/customizer", "/jnet/mainframe", "/jnet/payloads",
}
for _, dir in ipairs(dirs) do
    if not fs.exists(dir) then fs.makeDir(dir) end
end

-- Build file list
local filesToInstall = {}
for _, f in ipairs(CORE_FILES) do filesToInstall[#filesToInstall+1] = f end
for _, f in ipairs(NETWORK_MODULES) do filesToInstall[#filesToInstall+1] = f end
for _, f in ipairs(OFFENSE_MODULES) do filesToInstall[#filesToInstall+1] = f end
for _, f in ipairs(DEFENSE_MODULES) do filesToInstall[#filesToInstall+1] = f end
for _, f in ipairs(PAYLOADS) do filesToInstall[#filesToInstall+1] = f end

-- Always include mainframe files (needed for updates even on terminals)
for _, f in ipairs(MAINFRAME_FILES) do filesToInstall[#filesToInstall+1] = f end

local total = #filesToInstall
local installed = 0
local failed = 0

term.setTextColor(colors.white)
print("Downloading " .. total .. " files...")
print("")

for i, file in ipairs(filesToInstall) do
    -- Progress bar
    local pct = math.floor(i / total * 100)
    term.setCursorPos(1, 7)
    term.setTextColor(colors.gray)
    term.clearLine()
    local shortName = file
    if #shortName > 38 then shortName = "..." .. shortName:sub(-35) end
    term.write(shortName)

    term.setCursorPos(1, 8)
    term.clearLine()
    term.setTextColor(colors.lime)
    local barW = 30
    local filled = math.floor(barW * pct / 100)
    term.write("[" .. string.rep("=", filled) .. string.rep(" ", barW - filled) .. "] " .. pct .. "%")

    if download(file) then
        installed = installed + 1
    else
        failed = failed + 1
        term.setCursorPos(1, 9)
        term.setTextColor(colors.orange)
        term.clearLine()
        term.write("SKIP: " .. file)
    end
end

print("")
print("")
term.setTextColor(colors.lime)
print("Downloaded: " .. installed .. "/" .. total)
if failed > 0 then
    term.setTextColor(colors.orange)
    print("Failed: " .. failed)
end

-- ============================================================
-- First-time setup (skip for updates)
-- ============================================================

if not isUpdate then
    -- Shared secret
    if not fs.exists("/.jnet_secret") then
        print("")
        term.setTextColor(colors.white)
        write("Shared secret (ENTER=random): ")
        local secret = read("*")
        if secret == "" then
            secret = genSecret()
            print("Generated: " .. secret)
            term.setTextColor(colors.yellow)
            print("SAVE THIS! All computers need")
            print("the same secret.")
        end
        local f = fs.open("/.jnet_secret", "w")
        f.write(secret)
        f.close()
    end

    -- Startup
    print("")
    if isMainframe then
        local f = fs.open("/startup.lua", "w")
        f.write('shell.run("/jnet/mainframe/mainframe.lua")')
        f.close()
        term.setTextColor(colors.white)
        print("Startup: mainframe")
    else
        local f = fs.open("/startup.lua", "w")
        f.write('shell.run("/jnet/customizer/customizer.lua")')
        f.close()
        term.setTextColor(colors.white)
        print("Startup: customizer")
    end
end

-- ============================================================
-- Done
-- ============================================================

print("")
term.setTextColor(colors.lime)
print("================================")
if isUpdate then
    print("  UPDATE COMPLETE!")
else
    print("  JAVANET INSTALLED!")
end
print("================================")
print("")
term.setTextColor(colors.white)
print("Reboot? [Y/N] (auto in 5s)")

local timer = os.startTimer(5)
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
    elseif ev[1] == "timer" and ev[2] == timer then
        os.reboot()
    end
end
