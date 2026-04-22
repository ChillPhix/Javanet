-- customizer.lua
-- Javanet Terminal Customizer
-- Visual terminal builder with live preview on attached monitor.
-- Faction config is pulled from mainframe — not set per terminal.

local ui = dofile("/jnet/lib/jnet_ui.lua")
local config = dofile("/jnet/lib/jnet_config.lua")
local anim = dofile("/jnet/lib/jnet_anim.lua")
local monitor = dofile("/jnet/lib/jnet_monitor.lua")
local modules_lib = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")

-- ============================================================
-- State
-- ============================================================

local installed = {}
local allModules = {}
local factionConfig = nil
local terminalName = ""
local mainframeId = 0
local layoutMode = "auto"
local bootPreset = "military"
local catalogScroll = 0
local catalogSelected = 1
local screen = "connect" -- connect, builder, save, quit
local previewDirty = true

-- ============================================================
-- Module Discovery
-- ============================================================

local function discoverModules()
    modules_lib.discoverModules()
    allModules = {}
    for id, def in pairs(modules_lib.getAll()) do
        allModules[#allModules+1] = { id = id, def = def }
    end
    table.sort(allModules, function(a, b)
        if a.def.domain ~= b.def.domain then return a.def.domain < b.def.domain end
        return a.def.name < b.def.name
    end)
end

local function isInstalled(id)
    for _, m in ipairs(installed) do
        if m.id == id then return true end
    end
    return false
end

local function toggleModule(id)
    if isInstalled(id) then
        for i, m in ipairs(installed) do
            if m.id == id then table.remove(installed, i); break end
        end
    else
        if #installed >= modules_lib.MAX_MODULES then return false end
        installed[#installed+1] = { id = id, config = {} }
    end
    previewDirty = true
    return true
end

-- ============================================================
-- Preview Rendering (on monitor if available)
-- ============================================================

local function renderPreview()
    if not monitor.hasPrimary() then return end
    local mon = monitor.primaryMonitor.wrap
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local mw, mh = mon.getSize()

    -- Header
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.yellow)
    mon.setTextColor(colors.black)
    local title = (factionConfig and factionConfig.name) or "JAVANET"
    local pad = string.rep(" ", math.max(0, math.floor((mw - #title) / 2)))
    mon.write((pad .. title .. string.rep(" ", mw)):sub(1, mw))
    mon.setBackgroundColor(colors.black)

    -- Module panels
    if #installed == 0 then
        mon.setCursorPos(2, math.floor(mh / 2))
        mon.setTextColor(colors.gray)
        mon.write("No modules selected")
    else
        local panelH = math.max(3, math.floor((mh - 2) / #installed))
        for i, m in ipairs(installed) do
            local def = modules_lib.getDef(m.id)
            local name = def and def.name or m.id
            local py = 2 + (i - 1) * panelH
            if py + 2 > mh then break end
            mon.setTextColor(colors.cyan)
            mon.setCursorPos(2, py)
            mon.write(("[" .. name .. "]"):sub(1, mw - 2))
            mon.setTextColor(colors.gray)
            for row = py + 1, math.min(py + panelH - 1, mh - 1) do
                mon.setCursorPos(2, row)
                mon.write(string.rep("-", mw - 2))
            end
        end
    end

    -- Footer
    mon.setCursorPos(1, mh)
    mon.setBackgroundColor(colors.yellow)
    mon.setTextColor(colors.black)
    local footer = "Modules: " .. #installed .. "/" .. modules_lib.MAX_MODULES
    mon.write((footer .. string.rep(" ", mw)):sub(1, mw))

    previewDirty = false
end

-- ============================================================
-- Screen: Connect to Mainframe
-- ============================================================

local function screenConnect()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.clear()
    term.setCursorPos(1, 1)

    print("================================")
    print("   JAVANET TERMINAL SETUP")
    print("================================")
    print("")

    -- Check for existing config
    local existing = config.loadTerminal()
    if existing and existing.mainframeId and existing.mainframeId ~= 0 then
        mainframeId = existing.mainframeId
        terminalName = existing.terminalName or ""
        installed = existing.modules or {}
        layoutMode = existing.layoutMode or "auto"
        bootPreset = (existing.bootConfig or {}).preset or "military"
        term.setTextColor(colors.lime)
        print("Existing config found.")
        print("  Mainframe: #" .. mainframeId)
        print("  Terminal:  " .. terminalName)
        print("  Modules:   " .. #installed)
        print("")
        term.setTextColor(colors.white)
        print("[E] Edit this terminal")
        print("[N] Fresh setup")
        print("[Q] Quit")
        print("")

        while true do
            local ev = {os.pullEvent("key")}
            if ev[2] == keys.e then
                -- Load faction config
                factionConfig = config.loadFaction()
                if factionConfig then ui.applyIdentity(factionConfig) end
                screen = "builder"
                return
            elseif ev[2] == keys.n then
                installed = {}
                break
            elseif ev[2] == keys.q then
                screen = "quit"
                return
            end
        end
    end

    -- Ask for mainframe ID
    term.setTextColor(colors.white)
    print("")
    write("Mainframe computer ID: ")
    term.setTextColor(colors.yellow)
    local idStr = read()
    mainframeId = tonumber(idStr) or 0

    if mainframeId == 0 then
        term.setTextColor(colors.red)
        print("")
        print("Invalid ID.")
        print("On the mainframe, run: id")
        print("It shows the computer number.")
        sleep(3)
        return
    end

    -- Open modem
    term.setTextColor(colors.white)
    print("")
    print("Connecting to #" .. mainframeId .. "...")

    local ok, err = proto.openModem()
    if not ok then
        term.setTextColor(colors.red)
        print("No modem found!")
        print("Attach a modem and restart.")
        sleep(3)
        return
    end

    -- Try to pull faction config from mainframe
    local response = proto.request(mainframeId, "faction_query", {}, 5)
    if response and response.payload then
        factionConfig = response.payload
        term.setTextColor(colors.lime)
        print("Connected!")
        print("Faction: " .. (factionConfig.name or "?"))
        ui.applyIdentity(factionConfig)
        config.saveFaction(factionConfig)
        bootPreset = factionConfig.bootPreset or "military"
    else
        -- Mainframe didn't respond — manual fallback
        term.setTextColor(colors.orange)
        print("Mainframe not responding.")
        print("Setting up manually.")
        print("")

        term.setTextColor(colors.white)
        write("Faction name: ")
        term.setTextColor(colors.yellow)
        local fname = read()

        factionConfig = {
            name = (fname ~= "") and fname or "JAVANET",
            subtitle = "FACILITY",
            bootPreset = "military",
        }
        ui.applyIdentity(factionConfig)
        config.saveFaction(factionConfig)
    end

    sleep(1)
    screen = "builder"
end

-- ============================================================
-- Screen: Module Builder (with proper scrolling)
-- ============================================================

local function screenBuilder()
    term.setBackgroundColor(colors.black)
    term.clear()

    local W, H = term.getSize()

    -- Header bar
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.yellow)
    term.setTextColor(colors.black)
    local hdr = " " .. ((factionConfig and factionConfig.name) or "JAVANET") .. " - TERMINAL BUILDER "
    term.write((hdr .. string.rep(" ", W)):sub(1, W))
    term.setBackgroundColor(colors.black)

    -- Build flat display list (domain headers + modules)
    local displayList = {}
    local currentDomain = ""
    for i, mod in ipairs(allModules) do
        if mod.def.domain ~= currentDomain then
            currentDomain = mod.def.domain
            displayList[#displayList+1] = { type = "header", text = currentDomain:upper() }
        end
        displayList[#displayList+1] = { type = "module", text = mod.def.name, idx = i, id = mod.id }
    end

    -- Figure out which display row the selected module is on
    local selectedRow = 1
    for i, item in ipairs(displayList) do
        if item.type == "module" and item.idx == catalogSelected then
            selectedRow = i
            break
        end
    end

    -- List area
    local listTop = 3
    local listBot = H - 4
    local listH = listBot - listTop + 1

    -- Adjust scroll to keep selected row visible
    if selectedRow <= catalogScroll then
        catalogScroll = selectedRow - 1
    end
    if selectedRow > catalogScroll + listH then
        catalogScroll = selectedRow - listH
    end

    -- Column header
    term.setCursorPos(2, 2)
    term.setTextColor(colors.gray)
    term.write("Available Modules")
    term.setCursorPos(W - 16, 2)
    term.write(#installed .. "/" .. modules_lib.MAX_MODULES .. " selected")

    -- Render visible rows
    for r = 1, listH do
        local idx = catalogScroll + r
        local y = listTop + r - 1
        term.setCursorPos(1, y)

        if idx >= 1 and idx <= #displayList then
            local item = displayList[idx]

            if item.type == "header" then
                -- Domain header
                term.setTextColor(colors.orange)
                term.write("  -- " .. item.text .. " " .. string.rep("-", math.max(0, W - #item.text - 8)))
            else
                -- Module row
                local isSel = (item.idx == catalogSelected)
                local isOn = isInstalled(item.id)
                local mark = isOn and "[X]" or "[ ]"
                local arrow = isSel and "> " or "  "

                if isSel and isOn then
                    term.setTextColor(colors.lime)
                elseif isSel then
                    term.setTextColor(colors.yellow)
                elseif isOn then
                    term.setTextColor(colors.green)
                else
                    term.setTextColor(colors.white)
                end
                term.write((arrow .. mark .. " " .. item.text .. string.rep(" ", W)):sub(1, W))
            end
        end
    end

    -- Scroll indicator
    if #displayList > listH then
        local scrollPct = catalogScroll / math.max(1, #displayList - listH)
        local barH = math.max(1, math.floor(listH * listH / #displayList))
        local barPos = math.floor(scrollPct * (listH - barH))
        for r = 0, listH - 1 do
            term.setCursorPos(W, listTop + r)
            if r >= barPos and r < barPos + barH then
                term.setTextColor(colors.yellow)
                term.write("|")
            else
                term.setTextColor(colors.gray)
                term.write(":")
            end
        end
    end

    -- Description of selected module
    term.setCursorPos(1, H - 2)
    term.setTextColor(colors.gray)
    local selMod = allModules[catalogSelected]
    if selMod then
        local desc = selMod.def.description or ""
        term.write((" " .. desc .. string.rep(" ", W)):sub(1, W))
    end

    -- Installed list on bottom
    term.setCursorPos(1, H - 1)
    term.setTextColor(colors.cyan)
    local names = {}
    for _, m in ipairs(installed) do
        local d = modules_lib.getDef(m.id)
        names[#names+1] = d and d.name or m.id
    end
    local instLine = #names > 0 and table.concat(names, ", ") or "(none)"
    term.write((" " .. instLine .. string.rep(" ", W)):sub(1, W))

    -- Controls footer
    term.setCursorPos(1, H)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.write((" [Up/Dn]Scroll [Space]Toggle [S]ave+Deploy [Q]uit" .. string.rep(" ", W)):sub(1, W))
    term.setBackgroundColor(colors.black)
end

-- ============================================================
-- Screen: Save & Deploy
-- ============================================================

local function screenSave()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.clear()
    term.setCursorPos(1, 1)

    print("================================")
    print("     SAVE & DEPLOY")
    print("================================")
    print("")

    -- Terminal name
    if terminalName == "" then
        term.setTextColor(colors.white)
        write("Terminal name: ")
        term.setTextColor(colors.yellow)
        terminalName = read()
        if terminalName == "" then
            terminalName = "Terminal-" .. os.getComputerID()
        end
    else
        term.setTextColor(colors.white)
        print("Name: " .. terminalName)
        write("Keep? [Y/N]: ")
        term.setTextColor(colors.yellow)
        local yn = read()
        if yn:lower() == "n" then
            term.setTextColor(colors.white)
            write("New name: ")
            term.setTextColor(colors.yellow)
            terminalName = read()
            if terminalName == "" then
                terminalName = "Terminal-" .. os.getComputerID()
            end
        end
    end

    -- Set mainframeId on all modules
    for _, m in ipairs(installed) do
        m.config.mainframeId = mainframeId
    end

    -- Per-module config fields
    print("")
    term.setTextColor(colors.white)
    print("-- Module Settings --")
    print("")
    for _, m in ipairs(installed) do
        local def = modules_lib.getDef(m.id)
        if def and def.config_fields then
            term.setTextColor(colors.cyan)
            print("[" .. (def.name or m.id) .. "]")
            term.setTextColor(colors.white)
            for _, field in ipairs(def.config_fields) do
                if field.key ~= "mainframeId" then
                    local cur = m.config[field.key]
                    if cur == nil then cur = field.default end
                    if cur == nil then cur = "" end
                    write("  " .. field.label)
                    term.setTextColor(colors.gray)
                    write(" [" .. tostring(cur) .. "]")
                    term.setTextColor(colors.white)
                    write(": ")
                    term.setTextColor(colors.yellow)
                    local val = read()
                    term.setTextColor(colors.white)
                    if val ~= "" then
                        if field.type == "number" then
                            m.config[field.key] = tonumber(val) or cur
                        elseif field.type == "bool" then
                            local lv = val:lower()
                            m.config[field.key] = (lv == "true" or lv == "yes" or lv == "y" or lv == "1")
                        else
                            m.config[field.key] = val
                        end
                    elseif cur ~= "" then
                        m.config[field.key] = cur
                    end
                end
            end
            print("")
        end
    end

    -- Save
    local termCfg = {
        terminalName = terminalName,
        mainframeId = mainframeId,
        modules = installed,
        layoutMode = layoutMode,
        bootConfig = { preset = bootPreset },
        mirrorMonitor = monitor.hasPrimary(),
    }
    config.saveTerminal(termCfg)

    -- Write startup
    local f = fs.open("/startup.lua", "w")
    f.write('shell.run("/jnet/runtime/terminal.lua")')
    f.close()

    -- Done
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.lime)
    print("================================")
    print("   CONFIGURATION SAVED!")
    print("================================")
    print("")
    term.setTextColor(colors.white)
    print("Terminal:  " .. terminalName)
    print("Modules:   " .. #installed)
    print("Mainframe: #" .. mainframeId)
    print("")
    term.setTextColor(colors.yellow)
    print("Rebooting in 3 seconds...")
    sleep(3)
    os.reboot()
end

-- ============================================================
-- Main
-- ============================================================

local function main()
    discoverModules()
    monitor.detectMonitors()

    -- Check for existing faction config
    factionConfig = config.loadFaction()
    if factionConfig then
        ui.applyIdentity(factionConfig)
    end

    -- Check for existing terminal config
    local existing = config.loadTerminal()
    if existing and existing.mainframeId and existing.mainframeId ~= 0 then
        -- Already configured — go straight to edit
        mainframeId = existing.mainframeId
        terminalName = existing.terminalName or ""
        installed = existing.modules or {}
        layoutMode = existing.layoutMode or "auto"
        bootPreset = (existing.bootConfig or {}).preset or "military"
        screen = "connect" -- still show connect screen for E/N/Q choice
    end

    while true do
        if screen == "connect" then
            screenConnect()
        elseif screen == "builder" then
            screenBuilder()
            if previewDirty then renderPreview() end

            local ev = {os.pullEvent()}
            if ev[1] == "key" then
                if ev[2] == keys.up then
                    catalogSelected = math.max(1, catalogSelected - 1)
                elseif ev[2] == keys.down then
                    catalogSelected = math.min(#allModules, catalogSelected + 1)
                elseif ev[2] == keys.space then
                    local mod = allModules[catalogSelected]
                    if mod then toggleModule(mod.id) end
                elseif ev[2] == keys.s then
                    if #installed == 0 then
                        local _, H = term.getSize()
                        term.setCursorPos(2, H - 2)
                        term.setTextColor(colors.red)
                        term.write("Pick at least one module first!")
                        sleep(1)
                    else
                        screen = "save"
                    end
                elseif ev[2] == keys.q then
                    screen = "quit"
                end
            end
        elseif screen == "save" then
            screenSave()
        elseif screen == "quit" then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.clear()
            term.setCursorPos(1, 1)
            return
        end
    end
end

main()
