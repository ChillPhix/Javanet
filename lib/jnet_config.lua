-- jnet_config.lua
-- Configuration management for Javanet terminals.
-- Handles config file read/write and first-run setup wizards.
-- Place at /lib/jnet_config.lua on every Javanet computer.

local ui = dofile("/jnet/lib/jnet_ui.lua")
local M = {}

M.CONFIG_PATH = "/.jnet_config"
M.TERMINAL_PATH = "/.jnet_terminal.cfg"
M.FACTION_PATH = "/.jnet_faction.cfg"

-- ============================================================
-- Generic Config Read/Write
-- ============================================================

function M.load(path)
    path = path or M.CONFIG_PATH
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    local s = f.readAll(); f.close()
    local ok, data = pcall(textutils.unserialize, s)
    if ok and type(data) == "table" then return data end
    return nil
end

function M.save(data, path)
    path = path or M.CONFIG_PATH
    local f = fs.open(path, "w")
    f.write(textutils.serialize(data))
    f.close()
end

function M.exists(path)
    return fs.exists(path or M.CONFIG_PATH)
end

function M.delete(path)
    path = path or M.CONFIG_PATH
    if fs.exists(path) then fs.delete(path) end
end

-- ============================================================
-- Terminal Config
-- ============================================================

function M.loadTerminal()
    return M.load(M.TERMINAL_PATH)
end

function M.saveTerminal(cfg)
    M.save(cfg, M.TERMINAL_PATH)
end

-- ============================================================
-- Faction Config
-- ============================================================

function M.loadFaction()
    return M.load(M.FACTION_PATH)
end

function M.saveFaction(cfg)
    M.save(cfg, M.FACTION_PATH)
end

-- ============================================================
-- First-Run Wizard
-- ============================================================

function M.wizard(title, fields)
    local result = {}
    ui.clear()
    ui.header("JAVANET", title)
    local W, H = ui.getSize()
    local y = 3

    for _, field in ipairs(fields) do
        if y > H - 2 then
            ui.footer("Press any key for more...")
            os.pullEvent("key")
            ui.clear()
            ui.header("JAVANET", title)
            y = 3
        end

        if field.type == "string" then
            ui.write(2, y, field.label .. ": ", ui.FG, ui.BG)
            term.setCursorPos(2 + #field.label + 2, y)
            term.setTextColor(ui.ACCENT)
            term.setCursorBlink(true)
            local val = read(nil, nil, nil, field.default or "")
            term.setCursorBlink(false)
            if val == "" and field.default then val = field.default end
            result[field.key] = val
            y = y + 1

        elseif field.type == "password" then
            ui.write(2, y, field.label .. ": ", ui.FG, ui.BG)
            term.setCursorPos(2 + #field.label + 2, y)
            term.setTextColor(ui.ACCENT)
            term.setCursorBlink(true)
            local val = read("*")
            term.setCursorBlink(false)
            result[field.key] = val
            y = y + 1

        elseif field.type == "number" then
            ui.write(2, y, field.label .. ": ", ui.FG, ui.BG)
            term.setCursorPos(2 + #field.label + 2, y)
            term.setTextColor(ui.ACCENT)
            term.setCursorBlink(true)
            local val = read(nil, nil, nil, tostring(field.default or ""))
            term.setCursorBlink(false)
            result[field.key] = tonumber(val) or field.default or 0
            y = y + 1

        elseif field.type == "pick" then
            ui.write(2, y, field.label .. ":", ui.FG, ui.BG)
            y = y + 1
            local options = field.options
            if type(options) == "function" then options = options(result) end
            local sel = 1
            local listH = math.min(#options, H - y - 1)
            sel = ui.runScrollList(3, y, W - 4, listH, options, 1, 0)
            if type(sel) ~= "number" then sel = 1 end
            result[field.key] = options[sel]
            y = y + listH + 1

        elseif field.type == "color" then
            result[field.key] = ui.colorPicker(y, field.label, field.default or "yellow")
            y = y + 1

        elseif field.type == "bool" then
            local val = ui.confirm(y, field.label)
            result[field.key] = val
            y = y + 1

        elseif field.type == "multiline" then
            ui.write(2, y, field.label .. " (empty line to finish):", ui.FG, ui.BG)
            y = y + 1
            local lines = {}
            while true do
                term.setCursorPos(4, y)
                term.setTextColor(ui.ACCENT)
                term.setCursorBlink(true)
                local line = read()
                term.setCursorBlink(false)
                if line == "" then break end
                lines[#lines+1] = line
                y = y + 1
                if y > H - 1 then
                    ui.footer("Press any key for more...")
                    os.pullEvent("key")
                    ui.clear()
                    ui.header("JAVANET", title)
                    y = 3
                end
            end
            result[field.key] = lines
            y = y + 1

        elseif field.type == "clearance" then
            ui.write(2, y, "Number of clearance tiers (2-10): ", ui.FG, ui.BG)
            term.setCursorPos(36, y)
            term.setTextColor(ui.ACCENT)
            term.setCursorBlink(true)
            local numStr = read(nil, nil, nil, tostring(field.default or 6))
            term.setCursorBlink(false)
            local num = math.max(2, math.min(10, tonumber(numStr) or 6))
            y = y + 1
            local ranks = {}
            for i = 0, num - 1 do
                local defaultName = "Rank " .. i
                if i == 0 then defaultName = "Commander"
                elseif i == num - 1 then defaultName = "Guest" end
                ui.write(2, y, "Rank " .. i .. " (highest=" .. (i == 0 and "YES" or "no") .. "): ", ui.FG, ui.BG)
                term.setCursorPos(30, y)
                term.setTextColor(ui.ACCENT)
                term.setCursorBlink(true)
                local name = read(nil, nil, nil, defaultName)
                term.setCursorBlink(false)
                if name == "" then name = defaultName end
                ranks[#ranks+1] = { level = i, name = name }
                y = y + 1
                if y > H - 1 then
                    ui.footer("Press any key for more...")
                    os.pullEvent("key")
                    ui.clear()
                    ui.header("JAVANET", title)
                    y = 3
                end
            end
            result[field.key] = ranks
        end

        y = y + 1
    end

    return result
end

-- ============================================================
-- Load or Run Wizard
-- ============================================================

function M.loadOrWizard(title, fields, path)
    path = path or M.CONFIG_PATH
    local existing = M.load(path)
    if existing then return existing, false end
    local result = M.wizard(title, fields)
    M.save(result, path)
    return result, true
end

return M
