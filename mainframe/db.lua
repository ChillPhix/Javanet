-- db.lua
-- Javanet mainframe database module.
-- Persists all facility data to /jnet_db.
-- Custom clearance hierarchies, faction identity, full CRUD.

local M = {}

M.DB_PATH = "/jnet_db"
M.LOG_PATH = "/jnet_log"
M.MAX_LOG = 5000
M.MAX_MAIL = 500

local data = {}

-- ============================================================
-- Persistence
-- ============================================================

function M.load()
    if fs.exists(M.DB_PATH) then
        local f = fs.open(M.DB_PATH, "r")
        local s = f.readAll(); f.close()
        local ok, d = pcall(textutils.unserialize, s)
        if ok and type(d) == "table" then data = d end
    end
    M.ensureSchema()
end

function M.save()
    local f = fs.open(M.DB_PATH, "w")
    f.write(textutils.serialize(data))
    f.close()
end

function M.ensureSchema()
    data.identity = data.identity or {
        name = "JAVANET", subtitle = "SYSTEM", motto = "",
        fgColor = "yellow", bgColor = "black",
        bootPreset = "military", logoPath = "/.jnet_logo.txt",
        bootConfig = {},
    }
    data.clearance = data.clearance or {
        { level = 0, name = "Commander" },
        { level = 1, name = "Officer" },
        { level = 2, name = "Operator" },
        { level = 3, name = "Staff" },
        { level = 4, name = "Recruit" },
        { level = 5, name = "Guest" },
    }
    data.zones = data.zones or {}
    data.personnel = data.personnel or {}
    data.disks = data.disks or {}
    data.terminals = data.terminals or {}
    data.pending = data.pending or {}
    data.entities = data.entities or {}
    data.chambers = data.chambers or {}
    data.doors = data.doors or {}
    data.alarms = data.alarms or {}
    data.detectors = data.detectors or {}
    data.actions = data.actions or {}
    data.mail = data.mail or {}
    data.radio = data.radio or {}
    data.archive = data.archive or { folders = {}, documents = {} }
    data.sirenConfig = data.sirenConfig or {}
    data.passcodes = data.passcodes or { admin = nil, control = nil, issuer = nil }
    data.pins = data.pins or {}
    data.breaches = data.breaches or {}
    data.facilityState = data.facilityState or "normal"
    data.securityTiers = data.securityTiers or {}
    data.sessions = data.sessions or {}
    data.cooldowns = data.cooldowns or {}
    data.infections = data.infections or {}
    data.networkArchive = data.networkArchive or { folders = {}, documents = {} }
end

-- ============================================================
-- Identity
-- ============================================================

function M.getIdentity() return data.identity end

function M.setIdentity(id)
    for k, v in pairs(id) do data.identity[k] = v end
    M.save()
end

-- ============================================================
-- Clearance
-- ============================================================

function M.getClearance() return data.clearance end

function M.setClearance(ranks)
    data.clearance = ranks
    M.save()
end

function M.getClearanceName(level)
    for _, r in ipairs(data.clearance) do
        if r.level == level then return r.name end
    end
    return "Rank " .. level
end

function M.getMaxClearanceLevel()
    local max = 0
    for _, r in ipairs(data.clearance) do
        if r.level > max then max = r.level end
    end
    return max
end

-- ============================================================
-- Zones
-- ============================================================

function M.getZones() return data.zones end

function M.addZone(name)
    for _, z in ipairs(data.zones) do
        if z.name == name then return false, "Exists" end
    end
    data.zones[#data.zones+1] = {
        name = name, locked = false, occupants = {},
    }
    M.save()
    return true
end

function M.removeZone(name)
    for i, z in ipairs(data.zones) do
        if z.name == name then
            table.remove(data.zones, i)
            M.save()
            return true
        end
    end
    return false
end

function M.lockZone(name)
    for _, z in ipairs(data.zones) do
        if z.name == name then z.locked = true; M.save(); return true end
    end
    return false
end

function M.unlockZone(name)
    for _, z in ipairs(data.zones) do
        if z.name == name then z.locked = false; M.save(); return true end
    end
    return false
end

function M.setZoneOccupants(name, players)
    for _, z in ipairs(data.zones) do
        if z.name == name then z.occupants = players; M.save(); return true end
    end
    return false
end

-- ============================================================
-- Personnel
-- ============================================================

function M.getPersonnel() return data.personnel end

function M.addPerson(name, clearance, department, flags)
    data.personnel[name] = {
        name = name, clearance = tonumber(clearance) or 5,
        department = department or "General",
        flags = flags or {},
        suspended = false,
        created = os.epoch("utc"),
    }
    M.save()
    return true
end

function M.getPerson(name)
    return data.personnel[name]
end

function M.setPerson(name, field, value)
    if data.personnel[name] then
        data.personnel[name][field] = value
        M.save()
        return true
    end
    return false
end

function M.suspendPerson(name)
    return M.setPerson(name, "suspended", true)
end

function M.unsuspendPerson(name)
    return M.setPerson(name, "suspended", false)
end

function M.removePerson(name)
    data.personnel[name] = nil
    -- Remove associated disks
    local toRemove = {}
    for diskId, entry in pairs(data.disks) do
        if entry.name == name then toRemove[#toRemove+1] = diskId end
    end
    for _, diskId in ipairs(toRemove) do data.disks[diskId] = nil end
    M.save()
    return true
end

-- ============================================================
-- Disk / Card Management
-- ============================================================

function M.getDisks() return data.disks end

function M.registerDisk(diskId, name, clearance, department)
    data.disks[tostring(diskId)] = {
        name = name, clearance = tonumber(clearance) or 5,
        department = department or "General",
        registered = os.epoch("utc"),
        revoked = false,
    }
    M.save()
    return true
end

function M.getDisk(diskId)
    return data.disks[tostring(diskId)]
end

function M.revokeDisk(diskId)
    local d = data.disks[tostring(diskId)]
    if d then d.revoked = true; M.save(); return true end
    return false
end

function M.isDiskValid(diskId)
    local d = data.disks[tostring(diskId)]
    if not d then return false, "unknown" end
    if d.revoked then return false, "revoked" end
    local person = data.personnel[d.name]
    if person and person.suspended then return false, "suspended" end
    return true, d
end

-- ============================================================
-- Terminals
-- ============================================================

function M.getTerminals() return data.terminals end
function M.getPending() return data.pending end

function M.registerTerminal(id, info)
    data.terminals[tonumber(id) or id] = info
    M.save()
end

function M.addPending(id, info)
    data.pending[tonumber(id) or id] = info
    M.save()
end

function M.approvePending(id)
    id = tonumber(id) or id
    local p = data.pending[id]
    if p then
        data.terminals[id] = p
        data.pending[id] = nil
        M.save()
        return true, p
    end
    return false
end

function M.rejectPending(id)
    data.pending[tonumber(id) or id] = nil
    M.save()
end

-- ============================================================
-- Doors
-- ============================================================

function M.getDoors() return data.doors end

function M.registerDoor(compId, zone, minClearance, securityTier)
    data.doors[tonumber(compId) or compId] = {
        zone = zone, minClearance = tonumber(minClearance) or 5,
        securityTier = tonumber(securityTier) or 2,
        label = "", open = false,
    }
    M.save()
end

function M.getDoor(compId)
    return data.doors[tonumber(compId) or compId]
end

-- ============================================================
-- Entities
-- ============================================================

function M.getEntities() return data.entities end

function M.addEntity(id, info)
    data.entities[id] = {
        id = id,
        name = info.name or id,
        class = info.class or "Safe",
        zone = info.zone or "",
        status = info.status or "contained",
        threat = tonumber(info.threat) or 1,
        description = info.description or "",
        procedures = info.procedures or "",
        minClearance = tonumber(info.minClearance) or 3,
    }
    M.save()
    return true
end

function M.getEntity(id) return data.entities[id] end

function M.setEntityStatus(id, status)
    if data.entities[id] then
        data.entities[id].status = status
        M.save()
        return true
    end
    return false
end

-- ============================================================
-- Breaches
-- ============================================================

function M.getBreaches() return data.breaches end

function M.declareBreach(entityId)
    data.breaches[entityId] = {
        entity = entityId, time = os.epoch("utc"),
    }
    if data.entities[entityId] then
        data.entities[entityId].status = "breached"
    end
    M.save()
    return true
end

function M.endBreach(entityId)
    data.breaches[entityId] = nil
    if data.entities[entityId] then
        data.entities[entityId].status = "contained"
    end
    M.save()
    return true
end

-- ============================================================
-- Facility State
-- ============================================================

function M.getState() return data.facilityState end

function M.setState(state)
    data.facilityState = state
    M.save()
end

-- ============================================================
-- Passcodes & PINs
-- ============================================================

function M.getPasscodes() return data.passcodes end

function M.setPasscode(which, code)
    data.passcodes[which] = code
    M.save()
end

function M.checkPasscode(which, code)
    return data.passcodes[which] == code
end

function M.getPins() return data.pins end

function M.setPin(name, pin)
    data.pins[name] = pin
    M.save()
end

function M.checkPin(name, pin)
    return data.pins[name] == pin
end

-- ============================================================
-- Security Tiers
-- ============================================================

function M.getSecurityTier(resourceId)
    return data.securityTiers[tostring(resourceId)] or 2
end

function M.setSecurityTier(resourceId, tier)
    data.securityTiers[tostring(resourceId)] = math.max(1, math.min(5, tonumber(tier) or 2))
    M.save()
end

-- ============================================================
-- Session Tokens (from successful hacks)
-- ============================================================

function M.createSession(attackerId, resourceId, duration)
    duration = duration or 300
    local token = string.format("%08x", math.random(0, 0xFFFFFFFF))
    data.sessions[token] = {
        attacker = attackerId,
        resource = tostring(resourceId),
        expires = os.epoch("utc") / 1000 + duration,
        token = token,
    }
    M.save()
    return token
end

function M.validateSession(token)
    local s = data.sessions[token]
    if not s then return false end
    if os.epoch("utc") / 1000 > s.expires then
        data.sessions[token] = nil
        M.save()
        return false
    end
    return true, s
end

function M.cleanSessions()
    local now = os.epoch("utc") / 1000
    local cleaned = false
    for token, s in pairs(data.sessions) do
        if now > s.expires then
            data.sessions[token] = nil
            cleaned = true
        end
    end
    if cleaned then M.save() end
end

-- ============================================================
-- Cooldowns (escalating)
-- ============================================================

M.COOLDOWN_BASE = 30
M.COOLDOWN_MAX = 600

function M.getCooldown(attackerId, resourceId)
    local key = tostring(attackerId) .. ":" .. tostring(resourceId)
    local cd = data.cooldowns[key]
    if not cd then return 0 end
    local remaining = cd.until_time - os.epoch("utc") / 1000
    if remaining <= 0 then
        data.cooldowns[key] = nil
        return 0
    end
    return remaining
end

function M.addCooldown(attackerId, resourceId)
    local key = tostring(attackerId) .. ":" .. tostring(resourceId)
    local cd = data.cooldowns[key] or { failures = 0 }
    cd.failures = cd.failures + 1
    local duration = math.min(M.COOLDOWN_MAX, M.COOLDOWN_BASE * (2 ^ (cd.failures - 1)))
    cd.until_time = os.epoch("utc") / 1000 + duration
    data.cooldowns[key] = cd
    M.save()
    return duration
end

function M.resetCooldown(attackerId, resourceId)
    local key = tostring(attackerId) .. ":" .. tostring(resourceId)
    data.cooldowns[key] = nil
    M.save()
end

-- ============================================================
-- Infections (worms, agents, backdoors)
-- ============================================================

function M.getInfections() return data.infections end

function M.reportInfection(compId, infType, attackerFaction)
    data.infections[tonumber(compId) or compId] = {
        type = infType, attacker = attackerFaction,
        detected = os.epoch("utc"),
    }
    M.save()
end

function M.clearInfection(compId)
    data.infections[tonumber(compId) or compId] = nil
    M.save()
end

-- ============================================================
-- Mail System
-- ============================================================

function M.sendMail(from, to, subject, body)
    data.mail[#data.mail+1] = {
        id = #data.mail + 1,
        from = from, to = to,
        subject = subject, body = body,
        time = os.epoch("utc"),
        read = false, replied = false,
    }
    if #data.mail > M.MAX_MAIL then
        table.remove(data.mail, 1)
    end
    M.save()
    return true
end

function M.getInbox(name)
    local inbox = {}
    for _, m in ipairs(data.mail) do
        if m.to == name then inbox[#inbox+1] = m end
    end
    return inbox
end

function M.getSent(name)
    local sent = {}
    for _, m in ipairs(data.mail) do
        if m.from == name then sent[#sent+1] = m end
    end
    return sent
end

function M.markRead(mailId)
    for _, m in ipairs(data.mail) do
        if m.id == mailId then m.read = true; M.save(); return true end
    end
    return false
end

function M.deleteMail(mailId)
    for i, m in ipairs(data.mail) do
        if m.id == mailId then table.remove(data.mail, i); M.save(); return true end
    end
    return false
end

function M.getUnreadCount(name)
    local count = 0
    for _, m in ipairs(data.mail) do
        if m.to == name and not m.read then count = count + 1 end
    end
    return count
end

-- ============================================================
-- Network Archive (server-wide)
-- ============================================================

function M.getNetworkArchive() return data.networkArchive end

function M.addArchiveFolder(name, minClearance)
    data.networkArchive.folders[name] = {
        name = name, minClearance = tonumber(minClearance) or 5,
    }
    M.save()
    return true
end

function M.addArchiveDocument(folder, title, content, author)
    local id = tostring(os.epoch("utc")) .. "_" .. math.random(1000, 9999)
    data.networkArchive.documents[id] = {
        id = id, folder = folder, title = title,
        content = content, author = author or "System",
        created = os.epoch("utc"),
    }
    M.save()
    return id
end

function M.getArchiveDocuments(folder)
    local docs = {}
    for _, d in pairs(data.networkArchive.documents) do
        if d.folder == folder then docs[#docs+1] = d end
    end
    table.sort(docs, function(a, b) return a.created > b.created end)
    return docs
end

function M.deleteArchiveDocument(id)
    data.networkArchive.documents[id] = nil
    M.save()
end

-- ============================================================
-- Siren Config
-- ============================================================

function M.getSirenConfig() return data.sirenConfig end

function M.setSirenPattern(name, pattern)
    data.sirenConfig[name] = pattern
    M.save()
end

-- ============================================================
-- Logging
-- ============================================================

function M.log(msg)
    local f = fs.open(M.LOG_PATH, "a")
    local ts = os.epoch("utc")
    f.writeLine(string.format("[%s] %s", tostring(ts), msg))
    f.close()
end

function M.logFrom(source, action, detail)
    local msg = string.format("%s | %s", source, action)
    if detail then msg = msg .. " | " .. detail end
    M.log(msg)
end

function M.readLog(count)
    if not fs.exists(M.LOG_PATH) then return {} end
    local f = fs.open(M.LOG_PATH, "r")
    local lines = {}
    while true do
        local line = f.readLine()
        if not line then break end
        lines[#lines+1] = line
    end
    f.close()
    -- Return last N
    count = count or 50
    local start = math.max(1, #lines - count + 1)
    local result = {}
    for i = start, #lines do
        result[#result+1] = lines[i]
    end
    return result
end

function M.rotateLog()
    if not fs.exists(M.LOG_PATH) then return end
    local f = fs.open(M.LOG_PATH, "r")
    local lines = {}
    while true do
        local line = f.readLine()
        if not line then break end
        lines[#lines+1] = line
    end
    f.close()
    if #lines > M.MAX_LOG then
        local start = #lines - math.floor(M.MAX_LOG / 2)
        local f2 = fs.open(M.LOG_PATH, "w")
        for i = start, #lines do
            f2.writeLine(lines[i])
        end
        f2.close()
    end
end

-- ============================================================
-- Status Summary
-- ============================================================

function M.getStatus()
    local personnelCount = 0
    for _ in pairs(data.personnel) do personnelCount = personnelCount + 1 end

    local breachCount = 0
    for _ in pairs(data.breaches) do breachCount = breachCount + 1 end

    local entityCount = 0
    for _ in pairs(data.entities) do entityCount = entityCount + 1 end

    local terminalCount = 0
    for _ in pairs(data.terminals) do terminalCount = terminalCount + 1 end

    local pendingCount = 0
    for _ in pairs(data.pending) do pendingCount = pendingCount + 1 end

    local infectionCount = 0
    for _ in pairs(data.infections) do infectionCount = infectionCount + 1 end

    return {
        identity = data.identity,
        clearance = data.clearance,
        state = data.facilityState,
        zones = data.zones,
        personnel = personnelCount,
        breaches = breachCount,
        breachList = data.breaches,
        entities = entityCount,
        entityList = data.entities,
        terminals = terminalCount,
        pending = pendingCount,
        infections = infectionCount,
        sirenConfig = data.sirenConfig,
    }
end

return M
