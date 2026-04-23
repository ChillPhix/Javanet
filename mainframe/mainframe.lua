-- mainframe.lua
-- Javanet central mainframe server.
-- Handles all network message routing, auth, admin commands,
-- attack protocol responses, and facility management.
-- Fixed piece — not modular, but dashboard is customizable.

local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")
local config = dofile("/jnet/lib/jnet_config.lua")
local anim = dofile("/jnet/lib/jnet_anim.lua")
local monitor = dofile("/jnet/lib/jnet_monitor.lua")
local db = dofile("/jnet/mainframe/db.lua")
local puzzle = dofile("/jnet/lib/jnet_puzzle.lua")

-- ============================================================
-- First-Boot Wizard
-- ============================================================

local function firstBoot()
    ui.clear()
    ui.centerWrite(2, "JAVANET MAINFRAME SETUP", ui.ACCENT, ui.BG)
    ui.centerWrite(3, string.rep("=", 30), ui.DIM, ui.BG)
    sleep(0.5)

    local result = config.wizard("FACTION SETUP", {
        { key = "name", type = "string", label = "Faction name", default = "JAVANET" },
        { key = "subtitle", type = "string", label = "Subtitle", default = "FACILITY" },
        { key = "motto", type = "string", label = "Motto/tagline", default = "" },
        { key = "fgColor", type = "color", label = "Primary color", default = "yellow" },
        { key = "bgColor", type = "color", label = "Background color", default = "black" },
        { key = "bootPreset", type = "pick", label = "Boot style",
          options = {"military", "hacker", "corporate", "glitch", "stealth", "retro"} },
        { key = "clearance", type = "clearance", default = 6 },
        { key = "zones", type = "multiline", label = "Zone names" },
        { key = "adminPasscode", type = "password", label = "Admin passcode" },
        { key = "controlPasscode", type = "password", label = "Control passcode" },
        { key = "issuerPasscode", type = "password", label = "Issuer passcode" },
    })

    -- Apply to database
    db.setIdentity({
        name = result.name,
        subtitle = result.subtitle,
        motto = result.motto,
        fgColor = result.fgColor,
        bgColor = result.bgColor,
        bootPreset = result.bootPreset,
    })

    if result.clearance then
        db.setClearance(result.clearance)
    end

    if result.zones then
        for _, z in ipairs(result.zones) do
            if z ~= "" then db.addZone(z) end
        end
    end

    if result.adminPasscode and result.adminPasscode ~= "" then
        db.setPasscode("admin", result.adminPasscode)
    end
    if result.controlPasscode and result.controlPasscode ~= "" then
        db.setPasscode("control", result.controlPasscode)
    end
    if result.issuerPasscode and result.issuerPasscode ~= "" then
        db.setPasscode("issuer", result.issuerPasscode)
    end

    db.save()
    return result
end

-- ============================================================
-- Message Handlers
-- ============================================================

local handlers = {}

-- Terminal announcement
handlers.announce = function(senderId, payload)
    local info = {
        name = payload.name or "Terminal",
        modules = payload.modules or {},
        label = payload.label or "",
        announced = os.epoch("utc"),
    }
    -- Auto-approve if no approval queue needed, or add to pending
    if payload.autoApprove then
        db.registerTerminal(senderId, info)
        db.logFrom("MAINFRAME", "AUTO-APPROVED", "Terminal #" .. senderId .. " (" .. info.name .. ")")
        return { status = "approved" }
    else
        db.addPending(senderId, info)
        db.logFrom("MAINFRAME", "PENDING", "Terminal #" .. senderId .. " (" .. info.name .. ")")
        return { status = "pending" }
    end
end

-- Auth request (card swipe at door)
handlers.auth_request = function(senderId, payload)
    local diskId = payload.diskId
    local valid, diskData = db.isDiskValid(diskId)
    if not valid then
        db.logFrom("DOOR #" .. senderId, "DENIED", tostring(diskData) .. " disk:" .. tostring(diskId))
        return { granted = false, reason = diskData }
    end

    local door = db.getDoor(senderId)
    if not door then
        db.logFrom("DOOR #" .. senderId, "DENIED", "Unknown door")
        return { granted = false, reason = "unknown_door" }
    end

    if diskData.clearance > door.minClearance then
        db.logFrom("DOOR #" .. senderId, "DENIED", diskData.name .. " clearance:" .. diskData.clearance .. " needed:" .. door.minClearance)
        return { granted = false, reason = "clearance" }
    end

    -- Check zone lockdown
    for _, z in ipairs(db.getZones()) do
        if z.name == door.zone and z.locked then
            db.logFrom("DOOR #" .. senderId, "DENIED", diskData.name .. " zone locked:" .. door.zone)
            return { granted = false, reason = "lockdown" }
        end
    end

    db.logFrom("DOOR #" .. senderId, "GRANTED", diskData.name .. " (" .. db.getClearanceName(diskData.clearance) .. ")")
    return { granted = true, name = diskData.name, clearance = diskData.clearance, clearanceName = db.getClearanceName(diskData.clearance) }
end

-- Issue request (card creation)
handlers.issue_request = function(senderId, payload)
    if not db.checkPasscode("issuer", payload.passcode) then
        db.logFrom("ISSUER #" .. senderId, "DENIED", "Wrong passcode")
        return { success = false, reason = "passcode" }
    end
    db.registerDisk(payload.diskId, payload.name, payload.clearance, payload.department)
    if not db.getPerson(payload.name) then
        db.addPerson(payload.name, payload.clearance, payload.department)
    end
    db.logFrom("ISSUER #" .. senderId, "ISSUED", payload.name .. " clearance:" .. payload.clearance)
    return { success = true }
end

-- Status request
handlers.status_request = function(senderId, payload)
    return db.getStatus()
end

-- Full log request
handlers.full_log_request = function(senderId, payload)
    return { log = db.readLog(payload.count or 200) }
end

-- Admin command
handlers.admin_command = function(senderId, payload)
    if not db.checkPasscode("admin", payload.passcode) then
        db.logFrom("ADMIN #" .. senderId, "DENIED", "Wrong admin passcode")
        return { success = false, reason = "passcode" }
    end
    return handleAdminAction(senderId, payload)
end

-- Facility command (lockdown, breach, state)
handlers.facility_command = function(senderId, payload)
    local action = payload.action
    if action == "lockdown_zone" then
        db.lockZone(payload.zone)
        db.logFrom("TERMINAL #" .. senderId, "LOCKDOWN", payload.zone)
        proto.broadcast("facility_update", { type = "lockdown", zone = payload.zone })
        return { success = true }
    elseif action == "unlock_zone" then
        db.unlockZone(payload.zone)
        db.logFrom("TERMINAL #" .. senderId, "UNLOCK", payload.zone)
        proto.broadcast("facility_update", { type = "unlock", zone = payload.zone })
        return { success = true }
    elseif action == "declare_breach" then
        db.declareBreach(payload.entityId)
        db.logFrom("TERMINAL #" .. senderId, "BREACH", payload.entityId)
        proto.broadcast("facility_update", { type = "breach", entity = payload.entityId })
        return { success = true }
    elseif action == "end_breach" then
        db.endBreach(payload.entityId)
        db.logFrom("TERMINAL #" .. senderId, "BREACH END", payload.entityId)
        proto.broadcast("facility_update", { type = "breach_end", entity = payload.entityId })
        return { success = true }
    elseif action == "set_state" then
        db.setState(payload.state)
        db.logFrom("TERMINAL #" .. senderId, "STATE", payload.state)
        proto.broadcast("facility_update", { type = "state", state = payload.state })
        return { success = true }
    elseif action == "set_entity_status" then
        db.setEntityStatus(payload.entityId, payload.status)
        db.logFrom("TERMINAL #" .. senderId, "ENTITY STATUS", payload.entityId .. "=" .. payload.status)
        return { success = true }
    end
    return { success = false, reason = "unknown_action" }
end

-- Chamber info
handlers.chamber_info = function(senderId, payload)
    local entity = db.getEntity(payload.entityId)
    if not entity then return { found = false } end
    local breached = db.getBreaches()[payload.entityId] ~= nil
    return { found = true, entity = entity, breached = breached }
end

-- Entity list
handlers.entity_list = function(senderId, payload)
    return { entities = db.getEntities() }
end

-- Detector report
handlers.detector_report = function(senderId, payload)
    if payload.zone and payload.players then
        db.setZoneOccupants(payload.zone, payload.players)
    end
    return { ok = true }
end

-- Mail handlers
handlers.mail_send = function(senderId, payload)
    db.sendMail(payload.from, payload.to, payload.subject, payload.body)
    return { success = true }
end

handlers.mail_inbox = function(senderId, payload)
    return { inbox = db.getInbox(payload.name) }
end

handlers.mail_sent = function(senderId, payload)
    return { sent = db.getSent(payload.name) }
end

handlers.mail_read = function(senderId, payload)
    db.markRead(payload.mailId)
    return { success = true }
end

handlers.mail_delete = function(senderId, payload)
    db.deleteMail(payload.mailId)
    return { success = true }
end

-- Siren config
handlers.siren_config_request = function(senderId, payload)
    return { config = db.getSirenConfig() }
end

-- Archive
handlers.archive_list = function(senderId, payload)
    return { archive = db.getNetworkArchive() }
end

handlers.archive_get_docs = function(senderId, payload)
    return { documents = db.getArchiveDocuments(payload.folder) }
end

handlers.faction_query = function(senderId, payload)
    local identity = db.getIdentity()
    return {
        name = identity.name,
        subtitle = identity.subtitle,
        motto = identity.motto,
        fgColor = identity.fgColor,
        bgColor = identity.bgColor,
        bootPreset = identity.bootPreset,
        logoPath = identity.logoPath,
    }
end

-- ============================================================
-- Attack Protocol Handlers
-- ============================================================

local atkHandlers = {}

atkHandlers.probe = function(senderId, payload)
    -- IDS alert if active
    db.logFrom("IDS", "PROBE DETECTED", "From #" .. senderId)
    -- Return minimal info (attackers learn what's visible)
    return { type = "probe_response", name = db.getIdentity().name, id = os.getComputerID() }
end

atkHandlers.crack_request = function(senderId, payload)
    local resourceId = payload.resource
    local tier = db.getSecurityTier(resourceId)

    -- Check cooldown
    local cd = db.getCooldown(senderId, resourceId)
    if cd > 0 then
        db.logFrom("SECURITY", "CRACK BLOCKED", "Cooldown " .. math.ceil(cd) .. "s for #" .. senderId)
        return { type = "crack_denied", reason = "cooldown", remaining = math.ceil(cd) }
    end

    -- Generate puzzle
    local p = puzzle.generate(tier, {
        target = payload.targetName or ("Resource #" .. resourceId),
        modifier = payload.modifier,
    })

    if not p then
        return { type = "crack_denied", reason = "error" }
    end

    db.logFrom("SECURITY", "CRACK ATTEMPT", "Tier " .. tier .. " on resource #" .. resourceId .. " from #" .. senderId)

    -- Send puzzle parameters (not the solution!)
    return {
        type = "crack_puzzle",
        tier = tier,
        puzzleData = {
            typeName = p.typeName,
            tier = p.tier,
            timeLimit = p.timeLimit,
            maxAttempts = p.maxAttempts,
            -- Type-specific data (without answers)
            puzzleParams = serializePuzzleParams(p),
        },
    }
end

atkHandlers.crack_submit = function(senderId, payload)
    local resourceId = payload.resource
    local answer = payload.answer

    -- Validate answer against expected
    -- In practice, the puzzle runs client-side and we trust the result
    -- (since CC:T has no real security anyway)
    if payload.success then
        local tier = db.getSecurityTier(resourceId)
        local duration = 300 -- 5 minute session
        local token = db.createSession(senderId, resourceId, duration)
        db.resetCooldown(senderId, resourceId)
        db.logFrom("SECURITY", "BREACH", "Resource #" .. resourceId .. " cracked by #" .. senderId)
        proto.broadcast("facility_update", { type = "intrusion", resource = resourceId, attacker = senderId })
        return { type = "crack_success", token = token, duration = duration }
    else
        local cd = db.addCooldown(senderId, resourceId)
        db.logFrom("SECURITY", "CRACK FAILED", "Resource #" .. resourceId .. " by #" .. senderId .. " cooldown:" .. cd .. "s")
        return { type = "crack_failed", cooldown = cd }
    end
end

atkHandlers.deploy = function(senderId, payload)
    db.logFrom("SECURITY", "DEPLOY ATTEMPT", "Type:" .. (payload.deployType or "unknown") .. " from #" .. senderId)
    db.reportInfection(payload.targetComp or senderId, payload.deployType or "unknown", "attacker#" .. senderId)
    return { type = "deploy_ack" }
end

-- ============================================================
-- Admin Action Dispatch
-- ============================================================

function handleAdminAction(senderId, payload)
    local cmd = payload.command

    if cmd == "add_person" then
        db.addPerson(payload.name, payload.clearance, payload.department, payload.flags)
        db.logFrom("ADMIN #" .. senderId, "ADD PERSON", payload.name)
        return { success = true }

    elseif cmd == "set_person" then
        db.setPerson(payload.name, payload.field, payload.value)
        db.logFrom("ADMIN #" .. senderId, "SET PERSON", payload.name .. "." .. payload.field)
        return { success = true }

    elseif cmd == "suspend_person" then
        db.suspendPerson(payload.name)
        db.logFrom("ADMIN #" .. senderId, "SUSPEND", payload.name)
        return { success = true }

    elseif cmd == "remove_person" then
        db.removePerson(payload.name)
        db.logFrom("ADMIN #" .. senderId, "REMOVE PERSON", payload.name)
        return { success = true }

    elseif cmd == "revoke_disk" then
        db.revokeDisk(payload.diskId)
        db.logFrom("ADMIN #" .. senderId, "REVOKE DISK", tostring(payload.diskId))
        return { success = true }

    elseif cmd == "list_personnel" then
        return { success = true, personnel = db.getPersonnel() }

    elseif cmd == "list_disks" then
        return { success = true, disks = db.getDisks() }

    elseif cmd == "list_zones" then
        return { success = true, zones = db.getZones() }

    elseif cmd == "add_zone" then
        db.addZone(payload.zone)
        db.logFrom("ADMIN #" .. senderId, "ADD ZONE", payload.zone)
        return { success = true }

    elseif cmd == "remove_zone" then
        db.removeZone(payload.zone)
        db.logFrom("ADMIN #" .. senderId, "REMOVE ZONE", payload.zone)
        return { success = true }

    elseif cmd == "approve_pending" then
        local ok, info = db.approvePending(payload.pendingId)
        if ok then
            db.logFrom("ADMIN #" .. senderId, "APPROVED", "#" .. payload.pendingId)
            proto.send(tonumber(payload.pendingId), "approval", { status = "approved" })
        end
        return { success = ok }

    elseif cmd == "reject_pending" then
        db.rejectPending(payload.pendingId)
        db.logFrom("ADMIN #" .. senderId, "REJECTED", "#" .. payload.pendingId)
        return { success = true }

    elseif cmd == "list_pending" then
        return { success = true, pending = db.getPending() }

    elseif cmd == "add_entity" then
        db.addEntity(payload.entityId, payload)
        db.logFrom("ADMIN #" .. senderId, "ADD ENTITY", payload.entityId)
        return { success = true }

    elseif cmd == "set_identity" then
        db.setIdentity(payload.identity)
        db.logFrom("ADMIN #" .. senderId, "SET IDENTITY", payload.identity.name or "")
        proto.broadcast("identity_update", db.getIdentity())
        return { success = true }

    elseif cmd == "set_clearance" then
        db.setClearance(payload.ranks)
        db.logFrom("ADMIN #" .. senderId, "SET CLEARANCE", #payload.ranks .. " ranks")
        return { success = true }

    elseif cmd == "set_passcode" then
        db.setPasscode(payload.which, payload.code)
        db.logFrom("ADMIN #" .. senderId, "SET PASSCODE", payload.which)
        return { success = true }

    elseif cmd == "set_pin" then
        db.setPin(payload.name, payload.pin)
        db.logFrom("ADMIN #" .. senderId, "SET PIN", payload.name)
        return { success = true }

    elseif cmd == "set_security_tier" then
        db.setSecurityTier(payload.resource, payload.tier)
        db.logFrom("ADMIN #" .. senderId, "SET TIER", "Resource #" .. payload.resource .. " = T" .. payload.tier)
        return { success = true }

    elseif cmd == "register_door" then
        db.registerDoor(payload.compId, payload.zone, payload.minClearance, payload.securityTier)
        db.logFrom("ADMIN #" .. senderId, "REGISTER DOOR", "#" .. payload.compId .. " zone:" .. payload.zone)
        return { success = true }

    elseif cmd == "view_log" then
        return { success = true, log = db.readLog(payload.count or 50) }

    elseif cmd == "get_status" then
        return { success = true, status = db.getStatus() }

    elseif cmd == "archive_add_folder" then
        db.addArchiveFolder(payload.folderName, payload.minClearance)
        return { success = true }

    elseif cmd == "archive_add_doc" then
        local id = db.addArchiveDocument(payload.folder, payload.title, payload.content, payload.author)
        return { success = true, docId = id }

    elseif cmd == "archive_delete_doc" then
        db.deleteArchiveDocument(payload.docId)
        return { success = true }

    elseif cmd == "clear_infection" then
        db.clearInfection(payload.compId)
        db.logFrom("ADMIN #" .. senderId, "CLEAR INFECTION", "#" .. payload.compId)
        return { success = true }
    end

    return { success = false, reason = "unknown_command" }
end

-- ============================================================
-- Puzzle Param Serialization (strip answers)
-- ============================================================

local function serializePuzzleParams(p)
    -- Return only what the client needs to render, not solutions
    return {
        typeName = p.typeName,
        tier = p.tier,
    }
end

-- ============================================================
-- Main Dashboard
-- ============================================================

local function renderDashboard()
    local status = db.getStatus()
    ui.clear()
    ui.header(status.identity.name, status.identity.subtitle)
    local W, H = ui.getSize()

    -- State
    local stateColors = {
        normal = ui.OK, alert = ui.WARN,
        emergency = ui.ERR, lockdown = ui.ERR,
    }
    ui.write(2, 3, "State: ", ui.DIM, ui.BG)
    ui.write(9, 3, status.state:upper(), stateColors[status.state] or ui.FG, ui.BG)

    -- Computer ID
    ui.write(W - 12, 3, "ID: " .. os.getComputerID(), ui.DIM, ui.BG)

    -- Stats line
    ui.statusBar(5, {
        {"Personnel", status.personnel},
        {"Terminals", status.terminals},
        {"Entities", status.entities},
        {"Breaches", status.breaches, status.breaches > 0 and ui.ERR or ui.OK},
        {"Pending", status.pending, status.pending > 0 and ui.WARN or ui.DIM},
        {"Infections", status.infections, status.infections > 0 and ui.ERR or ui.DIM},
    })

    -- Zones
    ui.write(2, 7, "ZONES:", ui.FG, ui.BG)
    local zones = db.getZones()
    for i, z in ipairs(zones) do
        local row = 8 + i - 1
        if row > H - 6 then break end
        local lockStr = z.locked and "[LOCKED]" or "[open]"
        local lockCol = z.locked and ui.ERR or ui.OK
        local occStr = ""
        if z.occupants and #z.occupants > 0 then
            occStr = " (" .. #z.occupants .. " players)"
        end
        ui.write(4, row, z.name, ui.FG, ui.BG)
        ui.write(4 + #z.name + 1, row, lockStr, lockCol, ui.BG)
        ui.write(4 + #z.name + 1 + #lockStr + 1, row, occStr, ui.DIM, ui.BG)
    end

    -- Recent log
    local logStart = H - 4
    ui.write(2, logStart, "RECENT LOG:", ui.DIM, ui.BG)
    local logLines = db.readLog(3)
    for i, line in ipairs(logLines) do
        local row = logStart + i
        if row <= H - 1 then
            ui.write(2, row, ui.truncate(line, W - 2), ui.DIM, ui.BG)
        end
    end

    ui.footer("Ctrl+T: Admin CLI | Mainframe Online")
end

-- ============================================================
-- Main Loop
-- ============================================================

local function main()
    -- Load database
    db.load()

    -- Check for first boot
    local identity = db.getIdentity()
    if identity.name == "JAVANET" and not config.exists("/.jnet_mainframe_init") then
        firstBoot()
        config.save({ initialized = true }, "/.jnet_mainframe_init")
        identity = db.getIdentity()
    end

    -- Apply identity
    ui.applyIdentity(identity)
    ui.loadLogo(identity.logoPath)

    -- Open modem
    local ok, err = proto.openModem()
    if not ok then
        ui.clear()
        ui.centerWrite(5, "ERROR: " .. tostring(err), ui.ERR, ui.BG)
        ui.centerWrite(7, "Attach a wireless modem and reboot.", ui.DIM, ui.BG)
        sleep(999)
        return
    end

    -- Monitor setup — mirror to both computer + monitor BEFORE boot
    monitor.detectMonitors()
    if monitor.hasPrimary() then
        monitor.enableMirror()
    end

    -- Boot animation (now shows on both screens)
    anim.bootSequence({
        preset = identity.bootPreset or "military",
        module_names = {"Protocol", "Database", "Security", "Network", "Modules"},
    })

    -- Main event loop
    db.logFrom("MAINFRAME", "ONLINE", "ID #" .. os.getComputerID())

    local dashboardTimer = os.startTimer(1)
    local logRotateTimer = os.startTimer(300)
    local webDashTimer = os.startTimer(5)

    -- Web dashboard URL (set in /.jnet_dashboard_url)
    local webDashUrl = nil
    if fs.exists("/.jnet_dashboard_url") then
        local f = fs.open("/.jnet_dashboard_url", "r")
        webDashUrl = f.readAll():gsub("%s+", "")
        f.close()
        if #webDashUrl > 0 then
            db.logFrom("MAINFRAME", "DASHBOARD", "Web: " .. webDashUrl)
        else
            webDashUrl = nil
        end
    end

    local function pushWebDashboard()
        if not webDashUrl then return end
        local status = db.getStatus()
        local payload = textutils.serialiseJSON({
            identity = status.identity or {},
            state = status.state or "normal",
            zones = status.zones or {},
            breaches = status.breaches or {},
            terminals = status.terminals or {},
            personnel = status.personnel or {},
            infections = status.infections or {},
            logs = status.recentLogs or {},
            alerts = status.alerts or {},
        })
        if payload then
            pcall(function()
                http.post(webDashUrl .. "/api/status", payload, { ["Content-Type"] = "application/json" })
            end)
        end
    end

    renderDashboard()

    while true do
        local ev = {os.pullEventRaw()}

        if ev[1] == "terminate" then
            -- Allow access to admin CLI
            ui.clear()
            ui.centerWrite(5, "MAINFRAME PAUSED", ui.WARN, ui.BG)
            ui.centerWrite(7, "Type 'admin' for admin CLI", ui.DIM, ui.BG)
            ui.centerWrite(8, "Type 'resume' to resume", ui.DIM, ui.BG)
            term.setCursorPos(2, 10)
            term.setTextColor(ui.ACCENT)
            local cmd = read()
            if cmd == "admin" then
                shell.run("/jnet/mainframe/admin_cli.lua")
            end
            renderDashboard()

        elseif ev[1] == "rednet_message" then
            local senderId = ev[2]
            local msg = ev[3]
            local protocol = ev[4]

            if protocol == proto.PROTOCOL and type(msg) == "table" then
                local valid, verr = proto.verifyMessage(msg)
                if valid and msg.type then
                    local handler = handlers[msg.type]
                    if handler then
                        local response = handler(senderId, msg.payload or {})
                        if response then
                            proto.send(senderId, msg.type .. "_response", response)
                        end
                    else
                        db.logFrom("MAINFRAME", "UNKNOWN_MSG", msg.type .. " from #" .. senderId)
                    end
                end

            elseif protocol == proto.ATK_PROTOCOL and type(msg) == "table" then
                local atkHandler = atkHandlers[msg.type]
                if atkHandler then
                    local response = atkHandler(senderId, msg.payload or {})
                    if response then
                        proto.sendAtk(senderId, msg.type .. "_response", response)
                    end
                end
            elseif protocol == "JNET_UPDATE" and type(msg) == "table" and msg.type == "system_update" then
                shell.run("/jnet/update.lua", "listen")
                return
            end
            -- Always redraw after processing a message
            renderDashboard()

        elseif ev[1] == "timer" then
            if ev[2] == dashboardTimer then
                renderDashboard()
                db.cleanSessions()
                dashboardTimer = os.startTimer(1)
            elseif ev[2] == logRotateTimer then
                db.rotateLog()
                logRotateTimer = os.startTimer(300)
            elseif ev[2] == webDashTimer then
                pushWebDashboard()
                webDashTimer = os.startTimer(5)
            end
        end
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
        print("MAINFRAME CRASH: " .. tostring(err))
        print("Restarting in 5 seconds...")
        sleep(5)
    end
end
