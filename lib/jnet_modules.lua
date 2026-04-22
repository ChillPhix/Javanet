-- jnet_modules.lua
-- Module cache: return existing instance if already loaded
if _JNET_LOADED and _JNET_LOADED["jnet_modules"] then return _JNET_LOADED["jnet_modules"] end
if not _JNET_LOADED then _JNET_LOADED = {} end
-- Module registry and runtime loader for Javanet.
-- Manages module definitions, loading, lifecycle, and event routing.
-- Place at /lib/jnet_modules.lua on every Javanet computer.

local M = {}

-- ============================================================
-- Module Registry
-- ============================================================

M.registry = {}
M.loaded = {}
M.MAX_MODULES = 8

function M.register(id, def)
    def.id = id
    def.domain = def.domain or "network"
    def.min_size = def.min_size or { w = 15, h = 5 }
    def.pref_size = def.pref_size or { w = 25, h = 10 }
    def.scalable = def.scalable ~= false
    def.peripherals = def.peripherals or {}
    def.clearance = def.clearance or nil
    def.config_fields = def.config_fields or {}
    def.panel_style = def.panel_style or def.domain
    M.registry[id] = def
end

function M.getAll()
    return M.registry
end

function M.getByDomain(domain)
    local result = {}
    for id, def in pairs(M.registry) do
        if def.domain == domain then
            result[#result+1] = def
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function M.getDef(id)
    return M.registry[id]
end

-- ============================================================
-- Module Instance Management
-- ============================================================

function M.instantiate(id, config)
    local def = M.registry[id]
    if not def then return nil, "Module '" .. id .. "' not found" end

    local instance = {
        id = id,
        def = def,
        config = config or {},
        state = {},
        dirty = true,
        focused = false,
        panel = nil, -- assigned by layout engine
    }

    -- Call init if module defines it
    if def.init then
        local ok, err = pcall(def.init, instance)
        if not ok then return nil, "Init failed: " .. tostring(err) end
    end

    return instance
end

function M.loadModules(moduleList)
    M.loaded = {}
    for i, entry in ipairs(moduleList) do
        if i > M.MAX_MODULES then break end
        local id = type(entry) == "string" and entry or entry.id
        local config = type(entry) == "table" and entry.config or {}
        local inst, err = M.instantiate(id, config)
        if inst then
            M.loaded[#M.loaded+1] = inst
        end
    end
    return M.loaded
end

-- ============================================================
-- Module Lifecycle
-- ============================================================

function M.renderModule(instance, panel)
    if not instance or not instance.def.render then return end
    instance.panel = panel
    local ok, err = pcall(instance.def.render, instance, panel)
    if not ok then
        -- Draw error state
        local ui = dofile("/jnet/lib/jnet_ui.lua")
        ui.write(panel.x + 1, panel.y + 1, "ERR: " .. instance.id, colors.red, colors.black)
    end
    instance.dirty = false
end

function M.handleEvent(instance, event)
    if not instance or not instance.def.handleEvent then return nil end
    local ok, result = pcall(instance.def.handleEvent, instance, event)
    if ok then return result end
    return nil
end

function M.handleNetwork(instance, senderId, msg)
    if not instance or not instance.def.handleNetwork then return nil end
    local ok, result = pcall(instance.def.handleNetwork, instance, senderId, msg)
    if ok then return result end
    return nil
end

function M.tick(instance)
    if not instance or not instance.def.tick then return end
    local ok, _ = pcall(instance.def.tick, instance)
    if not ok then instance.dirty = true end
end

function M.cleanup(instance)
    if not instance or not instance.def.cleanup then return end
    pcall(instance.def.cleanup, instance)
end

-- ============================================================
-- Peripheral Checking
-- ============================================================

function M.checkPeripherals(id)
    local def = M.registry[id]
    if not def then return false, "Unknown module" end
    local missing = {}
    for _, pType in ipairs(def.peripherals) do
        local found = peripheral.find(pType)
        if not found then
            missing[#missing+1] = pType
        end
    end
    if #missing > 0 then
        return false, "Missing: " .. table.concat(missing, ", ")
    end
    return true
end

-- ============================================================
-- Module Discovery (scan modules/ directory)
-- ============================================================

function M.discoverModules()
    local dirs = {"modules/network", "modules/offense", "modules/defense"}
    for _, dir in ipairs(dirs) do
        local path = "/jnet/" .. dir
        if fs.exists(path) and fs.isDir(path) then
            for _, file in ipairs(fs.list(path)) do
                if file:match("%.lua$") then
                    local modPath = "/jnet/" .. dir .. "/" .. file
                    local ok, err = pcall(function()
                        dofile(modPath)
                    end)
                end
            end
        end
    end
end

-- ============================================================
-- Serialization Helpers (for config storage)
-- ============================================================

function M.serializeModuleList(instances)
    local list = {}
    for _, inst in ipairs(instances) do
        list[#list+1] = {
            id = inst.id,
            config = inst.config,
        }
    end
    return list
end

function M.getModuleNames(instances)
    local names = {}
    for _, inst in ipairs(instances) do
        local def = M.registry[inst.id] or {}
        names[#names+1] = def.name or inst.id
    end
    return names
end

function M.getDominantDomain(instances)
    local counts = { network = 0, offense = 0, defense = 0 }
    for _, inst in ipairs(instances) do
        local def = M.registry[inst.id]
        if def then
            counts[def.domain] = (counts[def.domain] or 0) + 1
        end
    end
    local max, domain = 0, "network"
    for d, c in pairs(counts) do
        if c > max then max = c; domain = d end
    end
    return domain
end

_JNET_LOADED["jnet_modules"] = M
return M
