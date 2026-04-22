-- customizer.lua
-- Javanet Terminal Customizer — Mouse-Driven UI
-- Tap modules to toggle, click buttons to navigate.

local ui = dofile("/jnet/lib/jnet_ui.lua")
local config = dofile("/jnet/lib/jnet_config.lua")
local anim = dofile("/jnet/lib/jnet_anim.lua")
local monitor = dofile("/jnet/lib/jnet_monitor.lua")
local modules_lib = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")

-- ============================================================
-- State
-- ============================================================

local installed = {}     -- { id=..., config={} }
local installedSet = {}  -- { [id] = true } for quick lookup
local allModules = {}    -- sorted list of { id, def }
local displayList = {}   -- flat list with headers for rendering
local factionConfig = nil
local terminalName = ""
local mainframeId = 0
local bootPreset = "military"
local catalogScroll = 0
local screen = "connect"
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

    -- Build flat display list
    displayList = {}
    local currentDomain = ""
    for i, mod in ipairs(allModules) do
        if mod.def.domain ~= currentDomain then
            currentDomain = mod.def.domain
            displayList[#displayList+1] = {
                type = "header",
                text = currentDomain:upper(),
                header = true,
                id = "hdr_" .. currentDomain,
            }
        end
        displayList[#displayList+1] = {
            type = "module",
            text = mod.def.name,
            id = mod.id,
            moduleIdx = i,
            desc = mod.def.description or "",
        }
    end
end

local function rebuildInstalledSet()
    installedSet = {}
    for _, m in ipairs(installed) do
        installedSet[m.id] = true
    end
end

local function toggleModule(id)
    if installedSet[id] then
        for i, m in ipairs(installed) do
            if m.id == id then table.remove(installed, i); break end
        end
    else
        if #installed >= modules_lib.MAX_MODULES then return false end
        installed[#installed+1] = { id = id, config = {} }
    end
    rebuildInstalledSet()
    previewDirty = true
    return true
end

-- ============================================================
-- Preview (monitor)
-- ============================================================

local function renderPreview()
    if not monitor.hasPrimary() then return end
    local mon = monitor.primaryMonitor.wrap
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local mw, mh = mon.getSize()

    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.yellow)
    mon.setTextColor(colors.black)
    local title = (factionConfig and factionConfig.name) or "JAVANET"
    local pad = string.rep(" ", math.max(0, math.floor((mw - #title) / 2)))
    mon.write((pad .. title .. string.rep(" ", mw)):sub(1, mw))
    mon.setBackgroundColor(colors.black)

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
        end
    end

    mon.setCursorPos(1, mh)
    mon.setBackgroundColor(colors.yellow)
    mon.setTextColor(colors.black)
    mon.write(("Modules: " .. #installed .. "/" .. modules_lib.MAX_MODULES .. string.rep(" ", mw)):sub(1, mw))
    previewDirty = false
end

-- ============================================================
-- Screen: Connect
-- ============================================================

local function screenConnect()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.clear()
    term.setCursorPos(1, 1)

    local W, H = term.getSize()

    -- Title
    ui.centerWrite(2, "J A V A N E T", colors.lime, colors.black)
    ui.centerWrite(3, "Terminal Setup", colors.gray, colors.black)
    ui.fillLine(4, "-", colors.green)

    -- Check existing config
    local existing = config.loadTerminal()
    if existing and existing.mainframeId and existing.mainframeId ~= 0 then
        mainframeId = existing.mainframeId
        terminalName = existing.terminalName or ""
        installed = existing.modules or {}
        rebuildInstalledSet()
        bootPreset = (existing.bootConfig or {}).preset or "military"

        ui.write(3, 6, "Existing config found:", colors.lime, colors.black)
        ui.write(3, 7, "Mainframe: #" .. mainframeId, colors.white, colors.black)
        ui.write(3, 8, "Terminal:  " .. terminalName, colors.white, colors.black)
        ui.write(3, 9, "Modules:   " .. #installed, colors.white, colors.black)

        local btns = ui.buttonRow(11, {
            { label = "Edit Terminal", id = "edit", style = "success" },
            { label = "New Setup", id = "new" },
            { label = "Quit", id = "quit", style = "danger" },
        }, "center")

        while true do
            local action, data = ui.waitForClick(btns)
            if action == "button" then
                if data.id == "edit" then
                    factionConfig = config.loadFaction()
                    if factionConfig then ui.applyIdentity(factionConfig) end
                    screen = "builder"
                    return
                elseif data.id == "new" then
                    installed = {}
                    rebuildInstalledSet()
                    break
                elseif data.id == "quit" then
                    screen = "quit"
                    return
                end
            end
        end
    end

    -- Fresh setup: ask for mainframe ID
    term.setBackgroundColor(colors.black)
    term.clear()
    ui.centerWrite(2, "J A V A N E T", colors.lime, colors.black)
    ui.centerWrite(3, "Terminal Setup", colors.gray, colors.black)
    ui.fillLine(4, "-", colors.green)

    ui.write(3, 6, "Enter the mainframe computer ID.", colors.white, colors.black)
    ui.write(3, 7, "(On mainframe, run 'id' to find it)", colors.gray, colors.black)
    ui.write(3, 9, "Mainframe ID: ", colors.white, colors.black)
    term.setCursorPos(17, 9)
    term.setTextColor(colors.yellow)
    term.setCursorBlink(true)
    local idStr = read()
    term.setCursorBlink(false)
    mainframeId = tonumber(idStr) or 0

    if mainframeId == 0 then
        ui.centerWrite(11, "Invalid ID!", colors.red, colors.black)
        sleep(2)
        return
    end

    -- Try connecting
    ui.write(3, 11, "Connecting to #" .. mainframeId .. "...", colors.white, colors.black)

    local ok = proto.openModem()
    if not ok then
        ui.write(3, 12, "No modem found! Attach one first.", colors.red, colors.black)
        ui.centerWrite(H - 1, "Click anywhere to continue", colors.gray, colors.black)
        os.pullEvent("mouse_click")
        return
    end

    local response = proto.request(mainframeId, "faction_query", {}, 5)
    if response and response.payload then
        factionConfig = response.payload
        ui.write(3, 12, "Connected! Faction: " .. (factionConfig.name or "?"), colors.lime, colors.black)
        ui.applyIdentity(factionConfig)
        config.saveFaction(factionConfig)
        bootPreset = factionConfig.bootPreset or "military"
    else
        ui.write(3, 12, "Could not reach mainframe.", colors.orange, colors.black)
        ui.write(3, 13, "Enter faction name manually:", colors.white, colors.black)
        term.setCursorPos(3, 14)
        term.setTextColor(colors.yellow)
        term.setCursorBlink(true)
        local fname = read()
        term.setCursorBlink(false)
        factionConfig = { name = (fname ~= "") and fname or "JAVANET", subtitle = "FACILITY", bootPreset = "military" }
        ui.applyIdentity(factionConfig)
        config.saveFaction(factionConfig)
    end

    sleep(1)
    screen = "builder"
end

-- ============================================================
-- Screen: Module Builder (fully clickable)
-- ============================================================

local function screenBuilder()
    term.setBackgroundColor(colors.black)
    term.clear()
    local W, H = term.getSize()

    -- Header
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.yellow)
    term.setTextColor(colors.black)
    term.write((" " .. ((factionConfig and factionConfig.name) or "JAVANET") .. " - BUILDER" .. string.rep(" ", W)):sub(1, W))
    term.setBackgroundColor(colors.black)

    -- Module count
    local countText = #installed .. "/" .. modules_lib.MAX_MODULES
    ui.write(W - #countText - 1, 2, countText, #installed >= modules_lib.MAX_MODULES and colors.red or colors.lime, colors.black)
    ui.write(2, 2, "Tap to toggle modules:", colors.gray, colors.black)

    -- Clickable module list with checkboxes
    local listTop = 3
    local listBot = H - 4
    local listH = listBot - listTop + 1

    -- Adjust scroll bounds
    if catalogScroll > math.max(0, #displayList - listH) then
        catalogScroll = math.max(0, #displayList - listH)
    end

    local listHits = ui.clickableList(1, listTop, W, listH, displayList, catalogScroll, installedSet, { checkboxes = true })

    -- Description of hovered/last clicked
    -- (we show a generic hint for now)
    ui.fillLine(H - 3, " ", nil, colors.black)

    -- Installed summary
    ui.write(1, H - 2, " ", colors.black, colors.black)
    local names = {}
    for _, m in ipairs(installed) do
        local d = modules_lib.getDef(m.id)
        names[#names+1] = d and d.name or m.id
    end
    local instLine = #names > 0 and table.concat(names, ", ") or "(none selected)"
    ui.write(1, H - 2, (" " .. instLine):sub(1, W), colors.cyan, colors.black)

    -- Bottom button bar
    local btns = ui.buttonRow(H - 1, {
        { label = "Save & Deploy", id = "save", style = "success" },
        { label = "Boot: " .. bootPreset, id = "boot" },
        { label = "Quit", id = "quit", style = "danger" },
    }, "center")

    -- Footer hint
    ui.write(1, H, (" Scroll: mouse wheel | Tap: toggle module"):sub(1, W), colors.gray, colors.black)

    return btns, listHits
end

-- ============================================================
-- Screen: Module Config (per-module settings)
-- ============================================================

local function screenModuleConfig()
    term.setBackgroundColor(colors.black)
    term.clear()
    local W, H = term.getSize()

    ui.centerWrite(1, "MODULE SETTINGS", colors.yellow, colors.black)
    ui.fillLine(2, "-", colors.green)

    local row = 3
    for _, m in ipairs(installed) do
        local def = modules_lib.getDef(m.id)
        if def and def.config_fields then
            ui.write(2, row, "[" .. (def.name or m.id) .. "]", colors.cyan, colors.black)
            row = row + 1
            for _, field in ipairs(def.config_fields) do
                if field.key ~= "mainframeId" then
                    local cur = m.config[field.key]
                    if cur == nil then cur = field.default end
                    if cur == nil then cur = "" end

                    if row >= H - 2 then
                        -- Screen full, let user scroll through with enter
                        ui.write(2, H - 1, "Press ENTER for more...", colors.gray, colors.black)
                        while true do
                            local ev = {os.pullEvent()}
                            if ev[1] == "key" and ev[2] == keys.enter then break end
                            if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then break end
                        end
                        term.setBackgroundColor(colors.black)
                        term.clear()
                        ui.centerWrite(1, "MODULE SETTINGS", colors.yellow, colors.black)
                        ui.fillLine(2, "-", colors.green)
                        row = 3
                    end

                    ui.write(3, row, field.label, colors.white, colors.black)
                    local valStr = " [" .. tostring(cur) .. "]"
                    ui.write(3 + #field.label, row, valStr, colors.gray, colors.black)
                    row = row + 1

                    term.setCursorPos(5, row)
                    term.setTextColor(colors.yellow)
                    term.setBackgroundColor(colors.black)
                    term.setCursorBlink(true)
                    local val = read()
                    term.setCursorBlink(false)
                    row = row + 1

                    if val ~= "" then
                        if field.type == "number" then
                            m.config[field.key] = tonumber(val) or cur
                        elseif field.type == "bool" then
                            local lv = val:lower()
                            m.config[field.key] = (lv == "true" or lv == "yes" or lv == "y" or lv == "1")
                        else
                            m.config[field.key] = val
                        end
                    elseif cur ~= nil and cur ~= "" then
                        m.config[field.key] = cur
                    end
                end
            end
            row = row + 1
        end
        m.config.mainframeId = mainframeId
    end
end

-- ============================================================
-- Screen: Save & Deploy
-- ============================================================

local function screenSave()
    term.setBackgroundColor(colors.black)
    term.clear()
    local W, H = term.getSize()

    ui.centerWrite(2, "SAVE & DEPLOY", colors.yellow, colors.black)
    ui.fillLine(3, "-", colors.green)

    -- Terminal name
    if terminalName == "" then
        ui.write(3, 5, "Terminal name:", colors.white, colors.black)
        term.setCursorPos(18, 5)
        term.setTextColor(colors.yellow)
        term.setCursorBlink(true)
        terminalName = read()
        term.setCursorBlink(false)
        if terminalName == "" then terminalName = "Terminal-" .. os.getComputerID() end
    else
        ui.write(3, 5, "Name: " .. terminalName, colors.white, colors.black)
        local btns = ui.buttonRow(6, {
            { label = "Keep Name", id = "keep", style = "success" },
            { label = "Change", id = "change" },
        }, "left")

        while true do
            local action, data = ui.waitForClick(btns)
            if action == "button" then
                if data.id == "change" then
                    ui.write(3, 7, "New name:", colors.white, colors.black)
                    term.setCursorPos(13, 7)
                    term.setTextColor(colors.yellow)
                    term.setCursorBlink(true)
                    terminalName = read()
                    term.setCursorBlink(false)
                    if terminalName == "" then terminalName = "Terminal-" .. os.getComputerID() end
                end
                break
            end
        end
    end

    -- Module-specific config
    screenModuleConfig()

    -- Save config
    local termCfg = {
        terminalName = terminalName,
        mainframeId = mainframeId,
        modules = installed,
        layoutMode = "auto",
        bootConfig = { preset = bootPreset },
        mirrorMonitor = monitor.hasPrimary(),
    }
    config.saveTerminal(termCfg)

    -- Write startup
    local f = fs.open("/startup.lua", "w")
    f.write('shell.run("/jnet/runtime/terminal.lua")')
    f.close()

    -- Done screen
    term.setBackgroundColor(colors.black)
    term.clear()
    ui.centerWrite(3, "CONFIGURATION SAVED!", colors.lime, colors.black)
    ui.fillLine(4, "=", colors.green)
    ui.write(3, 6, "Terminal:  " .. terminalName, colors.white, colors.black)
    ui.write(3, 7, "Modules:   " .. #installed, colors.white, colors.black)
    ui.write(3, 8, "Mainframe: #" .. mainframeId, colors.white, colors.black)
    ui.write(3, 9, "Boot:      " .. bootPreset, colors.white, colors.black)

    ui.centerWrite(11, "Rebooting in 3 seconds...", colors.yellow, colors.black)
    ui.centerWrite(12, "(tap to reboot now)", colors.gray, colors.black)

    local timer = os.startTimer(3)
    while true do
        local ev = {os.pullEvent()}
        if ev[1] == "timer" and ev[2] == timer then break end
        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then break end
        if ev[1] == "key" then break end
    end
    os.reboot()
end

-- ============================================================
-- Main Loop
-- ============================================================

local function main()
    discoverModules()
    monitor.detectMonitors()

    factionConfig = config.loadFaction()
    if factionConfig then ui.applyIdentity(factionConfig) end

    while true do
        if screen == "connect" then
            screenConnect()

        elseif screen == "builder" then
            local btns, listHits = screenBuilder()
            if previewDirty then renderPreview() end

            local action, data = ui.waitForClick(btns, listHits)

            if action == "button" then
                if data.id == "save" then
                    if #installed == 0 then
                        ui.alert("No Modules", "Select at least one module first!")
                    else
                        screen = "save"
                    end
                elseif data.id == "boot" then
                    local presets = {"military", "hacker", "corporate", "glitch", "stealth", "retro"}
                    local idx = 1
                    for i, p in ipairs(presets) do if p == bootPreset then idx = i; break end end
                    idx = (idx % #presets) + 1
                    bootPreset = presets[idx]
                elseif data.id == "quit" then
                    screen = "quit"
                end

            elseif action == "list_click" then
                -- Toggle the clicked module
                local clickedId = data.id
                -- Skip header clicks
                local isHeader = false
                for _, item in ipairs(displayList) do
                    if item.id == clickedId and item.header then isHeader = true; break end
                end
                if not isHeader then
                    toggleModule(clickedId)
                end

            elseif action == "scroll" then
                catalogScroll = catalogScroll + data.direction
                catalogScroll = math.max(0, math.min(#displayList - 10, catalogScroll))

            elseif action == "key" then
                if data.key == keys.q then screen = "quit" end
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
