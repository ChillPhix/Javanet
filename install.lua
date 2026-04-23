-- install.lua
-- Javanet Installer
-- One command: wget run https://raw.githubusercontent.com/ChillPhix/Javanet/main/install.lua
-- That's it. It asks you everything.

local REPO = "https://raw.githubusercontent.com/ChillPhix/Javanet/main/"

-- ============================================================
-- All files
-- ============================================================

local ALL_FILES = {
    "lib/jnet_proto.lua", "lib/jnet_ui.lua", "lib/jnet_anim.lua",
    "lib/jnet_config.lua", "lib/jnet_monitor.lua", "lib/jnet_gpu.lua",
    "lib/jnet_puzzle.lua", "lib/jnet_modules.lua",
    "runtime/terminal.lua", "customizer/customizer.lua", "update.lua",
    "mainframe/mainframe.lua", "mainframe/db.lua",
    "modules/network/card_reader.lua", "modules/network/door_lock.lua",
    "modules/network/card_issuer.lua", "modules/network/status_panel.lua",
    "modules/network/zone_panel.lua", "modules/network/breach_panel.lua",
    "modules/network/personnel_panel.lua", "modules/network/log_panel.lua",
    "modules/network/full_log.lua", "modules/network/clock.lua",
    "modules/network/lockdown_control.lua", "modules/network/breach_control.lua",
    "modules/network/entity_control.lua", "modules/network/entity_display.lua",
    "modules/network/entity_procedures.lua", "modules/network/facility_state.lua",
    "modules/network/panic_button.lua", "modules/network/siren.lua",
    "modules/network/player_detector.lua", "modules/network/archive_browser.lua",
    "modules/network/mail_client.lua", "modules/network/radio.lua",
    "modules/network/remote_door.lua", "modules/network/personnel_lookup.lua",
    "modules/network/admin_panel.lua", "modules/network/approval_queue.lua",
    "modules/offense/scanner.lua", "modules/offense/cracker.lua",
    "modules/offense/interceptor.lua", "modules/offense/replayer.lua",
    "modules/offense/card_spoofer.lua", "modules/offense/payload_deployer.lua",
    "modules/offense/worm_commander.lua", "modules/offense/agent_control.lua",
    "modules/offense/keylogger.lua", "modules/offense/hmac_cracker.lua",
    "modules/offense/signal_jammer.lua",
    "modules/defense/firewall.lua", "modules/defense/ids.lua",
    "modules/defense/deep_scan.lua", "modules/defense/tracer.lua",
    "modules/defense/counter_hack.lua", "modules/defense/antivirus.lua",
    "modules/defense/integrity_check.lua", "modules/defense/honeypot.lua",
    "modules/defense/quarantine.lua", "modules/defense/sentinel.lua",
    "payloads/lockout.lua", "payloads/worm.lua",
    "payloads/backdoor.lua", "payloads/agent.lua",
}

-- ============================================================
-- Helpers
-- ============================================================

local function cls()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
end

local function color(c)
    term.setTextColor(c)
end

local function ask(question, default)
    color(colors.white)
    write(question)
    if default then
        color(colors.gray)
        write(" [" .. default .. "]")
    end
    write(": ")
    color(colors.yellow)
    local answer = read()
    if answer == "" and default then return default end
    return answer
end

local function askSecret(question)
    color(colors.white)
    write(question .. ": ")
    color(colors.yellow)
    return read("*")
end

local function pause(msg)
    color(colors.gray)
    print(msg or "Press any key...")
    os.pullEvent("key")
end

local function genSecret()
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local s = ""
    for i = 1, 32 do
        local c = math.random(#chars)
        s = s .. chars:sub(c, c)
    end
    return s
end

-- ============================================================
-- Step 1: Welcome
-- ============================================================

cls()
color(colors.lime)
print("================================")
print("       J A V A N E T")
print("================================")
print("")
color(colors.white)
print("Welcome! This will set up")
print("Javanet on this computer.")
print("")
print("Just answer the questions below.")
print("")

-- ============================================================
-- Step 2: What is this computer?
-- ============================================================

color(colors.yellow)
print("What is this computer?")
print("")
color(colors.white)
print("  1. Mainframe (the server)")
print("     Only need ONE of these.")
print("")
print("  2. Terminal (door, security,")
print("     admin, display, etc.)")
print("")
print("  3. Update (already installed,")
print("     just get latest files)")
print("")

color(colors.yellow)
write("Pick 1, 2, or 3: ")
color(colors.white)

local choice = ""
while choice ~= "1" and choice ~= "2" and choice ~= "3" do
    choice = read()
    if choice ~= "1" and choice ~= "2" and choice ~= "3" then
        color(colors.red)
        write("Type 1, 2, or 3: ")
        color(colors.white)
    end
end

local isMainframe = (choice == "1")
local isUpdate = (choice == "3")

-- ============================================================
-- Step 3: Shared secret
-- ============================================================

if not isUpdate then
    cls()
    color(colors.lime)
    print("================================")
    print("  SHARED SECRET")
    print("================================")
    print("")

    if fs.exists("/.jnet_secret") then
        local f = fs.open("/.jnet_secret", "r")
        local existing = f.readAll():gsub("%s+", "")
        f.close()
        color(colors.white)
        print("This computer already has a")
        print("secret saved.")
        print("")
        color(colors.yellow)
        print("Keep existing secret? (Y/N)")
        write("> ")
        color(colors.white)
        local keep = read()
        if keep:lower() ~= "n" then
            -- Keep it
            print("")
            color(colors.lime)
            print("Keeping existing secret.")
        else
            fs.delete("/.jnet_secret")
        end
    end

    if not fs.exists("/.jnet_secret") then
        if isMainframe then
            color(colors.white)
            print("The mainframe needs a secret")
            print("that all computers share.")
            print("")
            print("You can type one, or press")
            print("ENTER to generate a random one.")
            print("")
            local secret = askSecret("Secret (ENTER=random)")
            if secret == "" then
                secret = genSecret()
                print("")
                color(colors.lime)
                print("Your secret: " .. secret)
                color(colors.yellow)
                print("")
                print("WRITE THIS DOWN!")
                print("Every other computer needs")
                print("this exact same secret.")
                pause("Press any key to continue...")
            end
            local f = fs.open("/.jnet_secret", "w")
            f.write(secret)
            f.close()
        else
            color(colors.white)
            print("Enter the shared secret from")
            print("your mainframe.")
            print("")
            print("(Check the mainframe computer")
            print("and run: type /.jnet_secret)")
            print("")
            local secret = ""
            while secret == "" do
                secret = ask("Secret", nil)
                if secret == "" then
                    color(colors.red)
                    print("Secret cannot be empty!")
                    color(colors.white)
                end
            end
            local f = fs.open("/.jnet_secret", "w")
            f.write(secret)
            f.close()
            print("")
            color(colors.lime)
            print("Secret saved!")
        end
    end
end

-- ============================================================
-- Step 4: Download files
-- ============================================================

cls()
color(colors.lime)
print("================================")
if isUpdate then
    print("  UPDATING FILES")
else
    print("  DOWNLOADING FILES")
end
print("================================")
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

local total = #ALL_FILES
local good = 0
local bad = 0

for i, file in ipairs(ALL_FILES) do
    local dest = "/jnet/" .. file
    local dir = fs.getDir(dest)
    if not fs.exists(dir) then fs.makeDir(dir) end
    if fs.exists(dest) then fs.delete(dest) end

    local pct = math.floor(i / total * 100)

    -- Progress
    term.setCursorPos(1, 5)
    color(colors.gray)
    term.clearLine()
    -- Shorten filename for display
    local short = file
    if #short > 35 then short = "..." .. short:sub(-32) end
    term.write(short)

    term.setCursorPos(1, 6)
    term.clearLine()
    color(colors.lime)
    local barW = 25
    local filled = math.floor(barW * pct / 100)
    term.write("[" .. string.rep("=", filled) .. string.rep(" ", barW - filled) .. "] " .. pct .. "%")

    local ok, response = pcall(http.get, REPO .. file)
    if ok and response then
        local content = response.readAll()
        response.close()
        local f = fs.open(dest, "w")
        f.write(content)
        f.close()
        good = good + 1
    else
        bad = bad + 1
    end
end

print("")
print("")
color(colors.lime)
print("Done! " .. good .. "/" .. total .. " files.")
if bad > 0 then
    color(colors.orange)
    print(bad .. " files failed to download.")
end
sleep(1)

-- ============================================================
-- Step 5: Set startup
-- ============================================================

if not isUpdate then
    if isMainframe then
        local f = fs.open("/startup.lua", "w")
        f.write('shell.run("/jnet/mainframe/mainframe.lua")')
        f.close()
    else
        local f = fs.open("/startup.lua", "w")
        f.write('shell.run("/jnet/customizer/customizer.lua")')
        f.close()
    end
end

-- ============================================================
-- Step 6: Done!
-- ============================================================

cls()
color(colors.lime)
print("================================")
print("         ALL DONE!")
print("================================")
print("")
color(colors.white)

if isUpdate then
    print("Files updated!")
    print("")
    print("Reboot to apply.")
elseif isMainframe then
    print("Mainframe is ready!")
    print("")
    print("After reboot it will walk you")
    print("through setting up your faction")
    print("name, colors, zones, etc.")
    print("")
    print("Your computer ID is: #" .. os.getComputerID())
    color(colors.yellow)
    print("Other computers need this number")
    print("to connect to the mainframe.")
else
    print("Terminal is ready!")
    print("")
    print("After reboot you will pick")
    print("which modules this terminal")
    print("runs (door, security, etc.)")
end

print("")
color(colors.yellow)
print("Rebooting in 5 seconds...")
print("(tap to reboot now)")

local timer = os.startTimer(5)
while true do
    local ev = {os.pullEvent()}
    if ev[1] == "timer" and ev[2] == timer then break end
    if ev[1] == "key" or ev[1] == "mouse_click" or ev[1] == "monitor_touch" then break end
end
os.reboot()
