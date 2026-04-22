-- terminal.lua
-- Universal Javanet terminal runtime engine.
-- Reads module config, loads modules, manages layout, routes events.
-- Every non-mainframe terminal runs this as startup.lua.

local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")
local config = dofile("/jnet/lib/jnet_config.lua")
local anim = dofile("/jnet/lib/jnet_anim.lua")
local monitor = dofile("/jnet/lib/jnet_monitor.lua")
local modules = dofile("/jnet/lib/jnet_modules.lua")

-- ============================================================
-- State
-- ============================================================

local termConfig = nil
local factionConfig = nil
local layout = nil
local focusedModule = 1
local tabIndex = 1
local mainframeId = nil
local running = true
local statusCache = nil
local statusTimer = nil

-- ============================================================
-- Initialization
-- ============================================================

local function loadConfigs()
    termConfig = config.loadTerminal()
    factionConfig = config.loadFaction()

    if not termConfig then
        -- No terminal config — run customizer or show setup
        ui.clear()
        ui.centerWrite(5, "NO TERMINAL CONFIGURED", ui.WARN, ui.BG)
        ui.centerWrite(7, "Run 'customizer' to set up this terminal", ui.DIM, ui.BG)
        ui.centerWrite(8, "Or run 'install mainframe' for a mainframe", ui.DIM, ui.BG)
        sleep(999)
        return false
    end

    mainframeId = termConfig.mainframeId
    return true
end

local function applyFaction()
    if factionConfig then
        ui.applyIdentity(factionConfig)
    end
    ui.loadLogo(factionConfig and factionConfig.logoPath or "/.jnet_logo.txt")
end

local function syncFaction()
    if not mainframeId then return end
    local response = proto.request(mainframeId, "status_request", {}, 3)
    if response and response.payload then
        local status = response.payload
        if status.identity then
            ui.applyIdentity(status.identity)
            ui.cacheIdentity()
            factionConfig = status.identity
            factionConfig.clearance = status.clearance
            config.saveFaction(factionConfig)
        end
        statusCache = status
    end
end

local function announceToMainframe()
    if not mainframeId then return end
    local moduleNames = modules.getModuleNames(modules.loaded)
    proto.send(mainframeId, "announce", {
        name = termConfig.terminalName or "Terminal",
        modules = moduleNames,
        label = os.getComputerLabel() or "",
        autoApprove = termConfig.autoApprove or false,
    })
end

-- ============================================================
-- Module Loading
-- ============================================================

local function loadAllModules()
    -- Discover available modules
    modules.discoverModules()

    -- Load configured modules
    local moduleList = termConfig.modules or {}
    modules.loadModules(moduleList)

    if #modules.loaded == 0 then
        ui.clear()
        ui.centerWrite(5, "NO MODULES CONFIGURED", ui.WARN, ui.BG)
        ui.centerWrite(7, "Run 'customizer' to add modules", ui.DIM, ui.BG)
        sleep(999)
        return false
    end
    return true
end

-- ============================================================
-- Layout
-- ============================================================

local function calculateLayout()
    local W, H = ui.getSize()
    local mode = termConfig.layoutMode or "auto"
    layout = monitor.calculateLayout(modules.loaded, W, H, mode)
end

local function renderAllModules()
    ui.clear()

    -- Header
    local domain = modules.getDominantDomain(modules.loaded)
    ui.header(ui.facilityName, ui.facilitySubtitle)

    -- Render each visible module in its panel
    for i, panel in ipairs(layout.panels) do
        if panel.visible then
            local inst = panel.module
            if inst then
                -- Draw panel border
                local borderDomain = inst.def and inst.def.domain or domain
                ui.panel(panel.x, panel.y, panel.w, panel.h, inst.def and inst.def.name or inst.id, borderDomain)

                -- Render module content inside panel
                local innerPanel = {
                    x = panel.x + 1,
                    y = panel.y + 1,
                    w = panel.w - 2,
                    h = panel.h - 2,
                }
                modules.renderModule(inst, innerPanel)
            end
        end
    end

    -- Footer
    local footerText = ""
    if layout.mode == "tabs" then
        footerText = "Tab " .. tabIndex .. "/" .. #modules.loaded .. " | [TAB] switch"
    elseif #modules.loaded > 1 then
        footerText = "[TAB] focus | " .. ui.facilityName
    else
        footerText = ui.facilityName
    end
    ui.footer(footerText)
end

-- ============================================================
-- Event Routing
-- ============================================================

local function routeEvent(ev)
    -- Route to focused module first
    if #modules.loaded > 0 and focusedModule <= #modules.loaded then
        local focused = modules.loaded[focusedModule]
        local result = modules.handleEvent(focused, ev)
        if result == "dirty" then
            focused.dirty = true
        end
    end

    -- Tab switching
    if ev[1] == "key" and ev[2] == keys.tab then
        if layout.mode == "tabs" then
            -- Switch visible tab
            for _, p in ipairs(layout.panels) do p.visible = false end
            tabIndex = tabIndex + 1
            if tabIndex > #layout.panels then tabIndex = 1 end
            layout.panels[tabIndex].visible = true
            focusedModule = tabIndex
            return true
        else
            focusedModule = focusedModule + 1
            if focusedModule > #modules.loaded then focusedModule = 1 end
            return true
        end
    end

    -- Mouse click: determine which panel was clicked
    if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
        local clickX = ev[1] == "monitor_touch" and ev[3] or ev[3]
        local clickY = ev[1] == "monitor_touch" and ev[4] or ev[4]
        for i, panel in ipairs(layout.panels) do
            if panel.visible and
               clickX >= panel.x and clickX < panel.x + panel.w and
               clickY >= panel.y and clickY < panel.y + panel.h then
                focusedModule = i
                local inst = panel.module
                if inst then
                    local localEv = {ev[1], ev[2], clickX - panel.x, clickY - panel.y}
                    modules.handleEvent(inst, localEv)
                end
                return true
            end
        end
    end

    return false
end

local function routeNetwork(senderId, msg)
    -- Route to all modules
    for _, inst in ipairs(modules.loaded) do
        modules.handleNetwork(inst, senderId, msg)
    end
end

local function tickModules()
    for _, inst in ipairs(modules.loaded) do
        modules.tick(inst)
    end
end

-- ============================================================
-- Main Loop
-- ============================================================

local function main()
    -- Open modem
    proto.openModem()

    -- Load configs
    if not loadConfigs() then return end

    -- Apply faction theming
    applyFaction()
    ui.loadCachedIdentity()

    -- Monitor setup — detect and MIRROR to both computer + monitor
    monitor.detectMonitors()
    local usingMonitor = false
    if monitor.hasPrimary() then
        monitor.enableMirror()  -- both computer screen AND monitor show the same thing
        usingMonitor = true
    end

    -- Boot animation (now renders on monitor if present)
    local bootConfig = termConfig.bootConfig or {}
    bootConfig.preset = bootConfig.preset or (factionConfig and factionConfig.bootPreset) or "military"

    -- Load modules first so we can show their names in boot
    if not loadAllModules() then return end

    bootConfig.module_names = modules.getModuleNames(modules.loaded)

    -- Check screen size — skip fancy boot on tiny screens
    local W, H = term.getSize()
    if W < 15 or H < 8 then
        -- Too small for full boot animation, just do a quick flash
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1, 1)
        term.setTextColor(colors.yellow)
        term.write("JAVANET")
        sleep(0.5)
    else
        anim.bootSequence(bootConfig)
    end

    -- Force tabs mode on small screens
    local layoutMode = termConfig.layoutMode or "auto"
    if layoutMode == "auto" then
        if W < 30 or H < 12 then
            layoutMode = "tabs"  -- small monitor: one module at a time
        end
    end
    termConfig.layoutMode = layoutMode

    -- Calculate layout
    calculateLayout()

    -- Announce to mainframe
    announceToMainframe()

    -- Sync faction
    syncFaction()

    -- Initial render
    renderAllModules()

    -- Timers
    statusTimer = os.startTimer(5)
    local renderTimer = os.startTimer(2)
    local tickTimer = os.startTimer(1)

    -- Event loop
    while running do
        local ev = {os.pullEventRaw()}

        if ev[1] == "terminate" then
            running = false
            break

        elseif ev[1] == "rednet_message" then
            local senderId = ev[2]
            local msg = ev[3]
            local protocol = ev[4]

            if protocol == proto.PROTOCOL then
                -- Verify and route
                routeNetwork(senderId, msg)
            elseif protocol == proto.ATK_PROTOCOL then
                -- Attack protocol — route to defense modules
                routeNetwork(senderId, msg)
            end

        elseif ev[1] == "timer" then
            if ev[2] == statusTimer then
                syncFaction()
                statusTimer = os.startTimer(10)
            elseif ev[2] == renderTimer then
                -- Check for dirty modules
                local needsRender = false
                for _, inst in ipairs(modules.loaded) do
                    if inst.dirty then needsRender = true; break end
                end
                if needsRender then renderAllModules() end
                renderTimer = os.startTimer(2)
            elseif ev[2] == tickTimer then
                tickModules()
                tickTimer = os.startTimer(1)
            end

        else
            -- Route input events
            local handled = routeEvent(ev)
            if handled then renderAllModules() end
        end
    end

    -- Cleanup
    for _, inst in ipairs(modules.loaded) do
        modules.cleanup(inst)
    end
end

-- Run with error recovery
while true do
    local ok, err = pcall(main)
    if not ok then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.red)
        term.clear()
        term.setCursorPos(1, 1)
        print("TERMINAL ERROR: " .. tostring(err))
        print("Restarting in 3 seconds...")
        sleep(3)
    else
        break
    end
end
