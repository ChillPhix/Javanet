-- install.lua
-- Universal Javanet Installer
-- Downloads and installs Javanet from GitHub.
-- Usage: wget run <url>/install.lua [mainframe|terminal|customizer]

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
-- Installer
-- ============================================================

term.setBackgroundColor(colors.black)
term.setTextColor(colors.yellow)
term.clear()
term.setCursorPos(1, 1)

print("=============================")
print("  JAVANET INSTALLER")
print("  Mode: " .. mode)
print("=============================")
print("")

-- Generate shared secret
local function genSecret()
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local s = ""
    for i = 1, 32 do
        local c = math.random(#chars)
        s = s .. chars:sub(c, c)
    end
    return s
end

-- Create directories
local dirs = {"lib", "modules", "modules/network", "modules/offense", "modules/defense", "runtime", "customizer", "mainframe", "payloads"}
for _, dir in ipairs(dirs) do
    if not fs.exists("/" .. dir) then fs.makeDir("/" .. dir) end
end

-- Determine files to install
local filesToInstall = {}
for _, f in ipairs(CORE_FILES) do filesToInstall[#filesToInstall+1] = f end
for _, f in ipairs(NETWORK_MODULES) do filesToInstall[#filesToInstall+1] = f end
for _, f in ipairs(OFFENSE_MODULES) do filesToInstall[#filesToInstall+1] = f end
for _, f in ipairs(DEFENSE_MODULES) do filesToInstall[#filesToInstall+1] = f end
for _, f in ipairs(PAYLOADS) do filesToInstall[#filesToInstall+1] = f end

if mode == "mainframe" then
    for _, f in ipairs(MAINFRAME_FILES) do filesToInstall[#filesToInstall+1] = f end
end

-- Download files (or copy if local)
print("Installing " .. #filesToInstall .. " files...")
local installed = 0
for _, file in ipairs(filesToInstall) do
    local dest = "/jnet/" .. file
    -- Create parent directory if needed
    local dir = fs.getDir(dest)
    if not fs.exists(dir) then
        fs.makeDir(dir)
    end
    -- In local mode, files are already present
    if fs.exists(dest) then
        installed = installed + 1
    else
        -- Try HTTP download
        local url = REPO .. file
        local ok, response = pcall(http.get, url)
        if ok and response then
            local content = response.readAll()
            response.close()
            local f = fs.open(dest, "w")
            f.write(content)
            f.close()
            installed = installed + 1
        else
            term.setTextColor(colors.orange)
            print("  SKIP: " .. file .. " (not found)")
            term.setTextColor(colors.yellow)
        end
    end
end

print("")
print("Installed: " .. installed .. "/" .. #filesToInstall)

-- Setup shared secret
if not fs.exists("/.jnet_secret") then
    print("")
    term.setTextColor(colors.white)
    write("Enter shared secret (or press ENTER for random): ")
    local secret = read("*")
    if secret == "" then
        secret = genSecret()
        print("Generated: " .. secret)
        print("SAVE THIS! All faction computers need the same secret.")
    end
    local f = fs.open("/.jnet_secret", "w")
    f.write(secret)
    f.close()
end

-- Setup startup
print("")
if mode == "mainframe" then
    local f = fs.open("/startup.lua", "w")
    f.write('shell.run("/jnet/mainframe/mainframe.lua")')
    f.close()
    print("Startup set to: mainframe")
    print("Reboot to start the mainframe.")
elseif mode == "customizer" then
    local f = fs.open("/startup.lua", "w")
    f.write('shell.run("/jnet/customizer/customizer.lua")')
    f.close()
    print("Startup set to: customizer")
    print("Reboot to configure this terminal.")
else
    -- Default terminal install: auto-launch customizer on first boot
    local f = fs.open("/startup.lua", "w")
    f.write('shell.run("/jnet/customizer/customizer.lua")')
    f.close()
    print("Startup set to: customizer")
    print("Reboot to configure this terminal.")
end

print("")
term.setTextColor(colors.lime)
print("JAVANET INSTALLED SUCCESSFULLY")
term.setTextColor(colors.white)
