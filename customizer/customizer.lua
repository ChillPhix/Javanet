-- customizer.lua
-- Javanet Terminal Customizer
-- Visual terminal builder with live preview on attached monitor.
-- Run on any Javanet computer to configure which modules it runs.

local ui = require("lib.jnet_ui")
local config = require("lib.jnet_config")
local anim = require("lib.jnet_anim")
local monitor = require("lib.jnet_monitor")
local modules_lib = require("lib.jnet_modules")

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
local bootConfig = {}
local catalogScroll = 0
local catalogSelected = 1
local screen = "faction" -- faction, clearance, builder, module_config, theme, save
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
    mon.setBackgroundColor(ui.BG)
    mon.clear()
    local mw, mh = mon.getSize()

    -- Header
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(ui.FG)
    mon.setTextColor(ui.BG)
    local title = ui.facilityName
    mon.write(string.rep(" ", math.floor((mw - #title) / 2)) .. title .. string.rep(" ", mw))

    -- Module panels
    mon.setBackgroundColor(ui.BG)
    if #installed == 0 then
        mon.setCursorPos(2, math.floor(mh / 2))
        mon.setTextColor(ui.DIM)
        mon.write("No modules installed")
    else
        local layout = monitor.calculateLayout(installed, mw, mh, layoutMode)
        for i, panel in ipairs(layout.panels) do
            if panel.visible then
                local def = modules_lib.getDef(panel.module.id)
                local name = def and def.name or panel.module.id
                local domain = def and def.domain or "network"
                local s = ui.getBorderStyle(domain)
                -- Draw border
                mon.setTextColor(ui.FG)
                mon.setCursorPos(panel.x, panel.y)
                local topLine = s.tl .. s.title_l .. name .. s.title_r .. string.rep(s.h, math.max(0, panel.w - #name - #s.tl - #s.title_l - #s.title_r - 1)) .. s.tr
                mon.write(topLine:sub(1, panel.w))
                for row = panel.y + 1, panel.y + panel.h - 2 do
                    mon.setCursorPos(panel.x, row)
                    mon.write(s.v .. string.rep(" ", panel.w - 2) .. s.v)
                end
                mon.setCursorPos(panel.x, panel.y + panel.h - 1)
                mon.write(s.bl .. string.rep(s.h, panel.w - 2) .. s.br)
            end
        end
    end

    -- Footer
    mon.setCursorPos(1, mh)
    mon.setBackgroundColor(ui.FG)
    mon.setTextColor(ui.BG)
    mon.write(ui.pad("Modules: " .. #installed .. "/" .. modules_lib.MAX_MODULES .. " | Layout: " .. layoutMode, mw))

    previewDirty = false
end

-- ============================================================
-- Screens
-- ============================================================

local function screenFaction()
    factionConfig = config.loadFaction() or {}

    local result = config.wizard("FACTION SETUP", {
        { key = "name", type = "string", label = "Faction name", default = factionConfig.name or "JAVANET" },
        { key = "subtitle", type = "string", label = "Subtitle", default = factionConfig.subtitle or "FACILITY" },
        { key = "motto", type = "string", label = "Motto/tagline", default = factionConfig.motto or "" },
        { key = "fgColor", type = "color", label = "Primary color", default = factionConfig.fgColor or "yellow" },
        { key = "bgColor", type = "color", label = "Background color", default = factionConfig.bgColor or "black" },
        { key = "bootPreset", type = "pick", label = "Boot style",
          options = {"military", "hacker", "corporate", "glitch", "stealth", "retro"} },
    })

    factionConfig = result
    ui.applyIdentity(result)
    bootPreset = result.bootPreset or "military"
    config.saveFaction(result)
    ui.cacheIdentity()
    screen = "builder"
end

local function screenBuilder()
    ui.clear()
    ui.header(ui.facilityName, "TERMINAL BUILDER")
    local W, H = ui.getSize()

    -- Split: left = catalog, right = installed
    local splitX = math.floor(W * 0.55)

    -- Left: catalog
    ui.write(2, 2, "MODULE CATALOG", ui.ACCENT, ui.BG)
    local currentDomain = ""
    local row = 3
    for i, mod in ipairs(allModules) do
        if row >= H - 2 then break end
        if mod.def.domain ~= currentDomain then
            currentDomain = mod.def.domain
            ui.write(2, row, currentDomain:upper() .. ":", ui.DIM, ui.BG)
            row = row + 1
        end
        local mark = isInstalled(mod.id) and "[X]" or "[ ]"
        local prefix = (i == catalogSelected) and "> " or "  "
        local col = i == catalogSelected and ui.ACCENT or ui.FG
        ui.write(2, row, prefix .. mark .. " " .. ui.truncate(mod.def.name, splitX - 10), col, ui.BG)
        row = row + 1
    end

    -- Right: installed
    ui.write(splitX + 1, 2, "INSTALLED (" .. #installed .. "/" .. modules_lib.MAX_MODULES .. ")", ui.ACCENT, ui.BG)
    for i, m in ipairs(installed) do
        local def = modules_lib.getDef(m.id)
        ui.write(splitX + 2, 3 + i - 1, (i .. ". " .. (def and def.name or m.id)):sub(1, W - splitX - 2), ui.FG, ui.BG)
    end

    -- Footer
    ui.write(2, H - 1, "[SPACE]Toggle [F]action [T]heme [L]ayout [B]oot preview [S]ave", ui.DIM, ui.BG)
    ui.write(2, H, "Layout: " .. layoutMode .. " | Boot: " .. bootPreset, ui.DIM, ui.BG)
end

local function screenSave()
    ui.clear()
    ui.header(ui.facilityName, "SAVE & DEPLOY")

    terminalName = ui.prompt(4, "Terminal name: ")
    mainframeId = tonumber(ui.prompt(6, "Mainframe ID: ")) or 0

    -- Apply mainframeId to all modules
    for _, m in ipairs(installed) do
        m.config.mainframeId = mainframeId
    end

    -- Save terminal config
    local termCfg = {
        terminalName = terminalName,
        mainframeId = mainframeId,
        modules = installed,
        layoutMode = layoutMode,
        bootConfig = {
            preset = bootPreset,
        },
        mirrorMonitor = monitor.hasPrimary(),
        autoApprove = true,
    }
    config.saveTerminal(termCfg)

    -- Set startup
    local f = fs.open("/startup.lua", "w")
    f.write('shell.run("/runtime/terminal.lua")')
    f.close()

    ui.clear()
    ui.centerWrite(5, "CONFIGURATION SAVED", ui.OK, ui.BG)
    ui.centerWrite(7, "Terminal: " .. terminalName, ui.FG, ui.BG)
    ui.centerWrite(8, "Modules: " .. #installed, ui.FG, ui.BG)
    ui.centerWrite(9, "Mainframe: #" .. mainframeId, ui.FG, ui.BG)
    ui.centerWrite(11, "Rebooting in 3 seconds...", ui.DIM, ui.BG)
    sleep(3)
    os.reboot()
end

-- ============================================================
-- Main Loop
-- ============================================================

local function main()
    -- Init
    discoverModules()
    monitor.detectMonitors()

    -- Load existing config
    local existing = config.loadTerminal()
    if existing then
        installed = existing.modules or {}
        layoutMode = existing.layoutMode or "auto"
        bootPreset = (existing.bootConfig or {}).preset or "military"
        mainframeId = existing.mainframeId or 0
        terminalName = existing.terminalName or ""
    end

    -- Load faction
    factionConfig = config.loadFaction()
    if factionConfig then
        ui.applyIdentity(factionConfig)
    end
    ui.loadCachedIdentity()

    -- Check if first run
    if not factionConfig then
        screen = "faction"
    else
        screen = "builder"
    end

    while true do
        if screen == "faction" then
            screenFaction()
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
                elseif ev[2] == keys.f then
                    screen = "faction"
                elseif ev[2] == keys.l then
                    local modes = {"auto", "split", "grid", "tabs", "focus"}
                    local idx = 1
                    for i, m in ipairs(modes) do if m == layoutMode then idx = i; break end end
                    idx = (idx % #modes) + 1
                    layoutMode = modes[idx]
                    previewDirty = true
                elseif ev[2] == keys.b then
                    -- Boot preview
                    ui.clear()
                    anim.bootSequence({
                        preset = bootPreset,
                        module_names = modules_lib.getModuleNames(installed),
                    })
                    sleep(1)
                elseif ev[2] == keys.t then
                    local presets = {"military", "hacker", "corporate", "glitch", "stealth", "retro"}
                    local idx = 1
                    for i, p in ipairs(presets) do if p == bootPreset then idx = i; break end end
                    idx = (idx % #presets) + 1
                    bootPreset = presets[idx]
                elseif ev[2] == keys.s then
                    screenSave()
                elseif ev[2] == keys.q then
                    return
                end
            end
        end
    end
end

main()
