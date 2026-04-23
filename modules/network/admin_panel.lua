-- admin_panel.lua — Network Module
-- Full admin: manage personnel, doors, entities, zones, and more.
-- Tap menu items to activate. Tap login to authenticate.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

local MENU = {
    { id = "add_person",    label = "Add Personnel" },
    { id = "add_zone",      label = "Add Zone" },
    { id = "add_entity",    label = "Add Entity" },
    { id = "register_door", label = "Register Door" },
    { id = "issue_card",    label = "Issue Card" },
    { id = "set_tier",      label = "Set Security Tier" },
    { id = "add_archive",   label = "Add Archive Folder" },
    { id = "set_identity",  label = "Set Identity" },
    { id = "set_passcode",  label = "Set Passcode" },
}

-- Run an admin form: takes over the screen, returns to module after
local function adminForm(self, title, fields)
    ui.clear()
    ui.header(ui.facilityName, title)

    local result = {}
    local row = 4
    for _, field in ipairs(fields) do
        ui.write(3, row, field.label .. ":", ui.FG, ui.BG)
        row = row + 1
        term.setCursorPos(5, row)
        term.setTextColor(ui.ACCENT)
        term.setBackgroundColor(ui.BG)
        term.setCursorBlink(true)
        if field.type == "password" then
            result[field.key] = read("*")
        else
            result[field.key] = read()
        end
        term.setCursorBlink(false)
        row = row + 1
    end
    return result
end

local function sendAdmin(self, command, data)
    local mfId = self.config.mainframeId
    if not mfId then return end
    data = data or {}
    data.command = command
    data.passcode = self.state.adminPass or ""
    proto.send(tonumber(mfId), "admin_command", data)
end

modules.register("admin_panel", {
    name = "Admin Panel",
    domain = "network",
    min_size = { w = 25, h = 8 },
    pref_size = { w = 40, h = 16 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self)
        self.state.scroll = 0
        self.state.authenticated = false
        self.state.adminPass = ""
        self.state.selected = 1
        self.state.statusMsg = ""
        self.state.statusColor = ui.DIM
    end,

    render = function(self, panel)
        self._panel = panel
        local lines = {}

        if not self.state.authenticated then
            lines[#lines+1] = {text = "ADMIN PANEL", color = ui.FG}
            lines[#lines+1] = ""
            lines[#lines+1] = {text = "Authentication required.", color = ui.DIM}
            lines[#lines+1] = ""
            lines[#lines+1] = {text = "[ TAP TO LOGIN ]", color = ui.WARN}
        else
            lines[#lines+1] = {text = "ADMIN PANEL", color = ui.FG}
            lines[#lines+1] = ""

            for i, item in ipairs(MENU) do
                local prefix = (i == self.state.selected) and "> " or "  "
                lines[#lines+1] = {
                    text = prefix .. item.label,
                    color = i == self.state.selected and ui.ACCENT or ui.FG,
                }
            end

            lines[#lines+1] = ""
            lines[#lines+1] = {text = "Tap item or use arrows+ENTER", color = ui.DIM}

            if self.state.statusMsg and #self.state.statusMsg > 0 then
                lines[#lines+1] = {text = self.state.statusMsg, color = self.state.statusColor or ui.DIM}
            end
        end

        self.state.scroll = ui.renderPanelContent(panel, lines, self.state.scroll)
    end,

    handleEvent = function(self, ev)
        ui.handlePanelScroll(self, ev)

        -- Login on tap or enter when not authenticated
        if not self.state.authenticated then
            if ev[1] == "mouse_click" or ev[1] == "monitor_touch" or
               (ev[1] == "key" and ev[2] == keys.enter) then
                local result = adminForm(self, "ADMIN LOGIN", {
                    { key = "pass", label = "Admin Passcode", type = "password" },
                })
                self.state.adminPass = result.pass or ""
                self.state.authenticated = true
                self.dirty = true
            end
            return
        end

        -- Menu navigation
        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local cy = ev[1] == "monitor_touch" and ev[4] or ev[4]
            if self._panel then
                -- Menu items start at line 3 in the rendered content (after header + blank)
                local relY = cy - self._panel.y - 1  -- offset for header+blank
                if relY >= 1 and relY <= #MENU then
                    self.state.selected = relY
                    self:_runAction(MENU[relY].id)
                end
            end

        elseif ev[1] == "key" then
            if ev[2] == keys.up then
                self.state.selected = math.max(1, self.state.selected - 1)
                self.dirty = true
            elseif ev[2] == keys.down then
                self.state.selected = math.min(#MENU, self.state.selected + 1)
                self.dirty = true
            elseif ev[2] == keys.enter then
                local item = MENU[self.state.selected]
                if item then self:_runAction(item.id) end
            elseif ev[2] == keys.backspace then
                self.state.authenticated = false
                self.state.statusMsg = ""
                self.dirty = true
            end
        end
    end,
})

-- Action handler
local def = modules.getDef("admin_panel")
function def._runAction(self, actionId)
    if actionId == "add_person" then
        local r = adminForm(self, "ADD PERSONNEL", {
            { key = "name", label = "Name" },
            { key = "clearance", label = "Clearance Level (number)" },
            { key = "department", label = "Department" },
        })
        if r.name and #r.name > 0 then
            sendAdmin(self, "add_person", {
                name = r.name,
                clearance = tonumber(r.clearance) or 1,
                department = r.department or "",
            })
            self.state.statusMsg = "Added: " .. r.name
            self.state.statusColor = ui.OK
        end

    elseif actionId == "add_zone" then
        local r = adminForm(self, "ADD ZONE", {
            { key = "zone", label = "Zone Name" },
        })
        if r.zone and #r.zone > 0 then
            sendAdmin(self, "add_zone", { zone = r.zone })
            self.state.statusMsg = "Zone added: " .. r.zone
            self.state.statusColor = ui.OK
        end

    elseif actionId == "add_entity" then
        local r = adminForm(self, "ADD ENTITY", {
            { key = "entityId", label = "Entity ID (e.g. SCP-173)" },
            { key = "name", label = "Name" },
            { key = "class", label = "Class (Safe/Euclid/Keter)" },
            { key = "zone", label = "Containment Zone" },
            { key = "description", label = "Description" },
        })
        if r.entityId and #r.entityId > 0 then
            sendAdmin(self, "add_entity", r)
            self.state.statusMsg = "Entity added: " .. r.entityId
            self.state.statusColor = ui.OK
        end

    elseif actionId == "register_door" then
        local r = adminForm(self, "REGISTER DOOR", {
            { key = "compId", label = "Door Computer ID" },
            { key = "name", label = "Door Name" },
            { key = "zone", label = "Zone" },
            { key = "minClearance", label = "Min Clearance (number)" },
            { key = "securityTier", label = "Security Tier (1-5)" },
        })
        if r.compId then
            sendAdmin(self, "register_door", {
                compId = tonumber(r.compId),
                name = r.name or "",
                zone = r.zone or "",
                minClearance = tonumber(r.minClearance) or 1,
                securityTier = tonumber(r.securityTier) or 2,
            })
            self.state.statusMsg = "Door registered: #" .. r.compId
            self.state.statusColor = ui.OK
        end

    elseif actionId == "issue_card" then
        local r = adminForm(self, "ISSUE CARD", {
            { key = "diskId", label = "Floppy Disk ID" },
            { key = "owner", label = "Owner Name" },
            { key = "clearance", label = "Clearance Level (number)" },
        })
        if r.diskId then
            sendAdmin(self, "register_disk", {
                diskId = tonumber(r.diskId) or r.diskId,
                owner = r.owner or "",
                clearance = tonumber(r.clearance) or 1,
            })
            self.state.statusMsg = "Card issued: disk " .. r.diskId
            self.state.statusColor = ui.OK
        end

    elseif actionId == "set_tier" then
        local r = adminForm(self, "SET SECURITY TIER", {
            { key = "resource", label = "Computer ID or Resource" },
            { key = "tier", label = "Tier (1-5)" },
        })
        if r.resource then
            sendAdmin(self, "set_security_tier", {
                resource = r.resource,
                tier = tonumber(r.tier) or 2,
            })
            self.state.statusMsg = "Tier set: " .. r.resource .. " = T" .. (r.tier or "?")
            self.state.statusColor = ui.OK
        end

    elseif actionId == "add_archive" then
        local r = adminForm(self, "ADD ARCHIVE FOLDER", {
            { key = "folderName", label = "Folder Name" },
            { key = "minClearance", label = "Min Clearance (number)" },
        })
        if r.folderName and #r.folderName > 0 then
            sendAdmin(self, "archive_add_folder", {
                folderName = r.folderName,
                minClearance = tonumber(r.minClearance) or 1,
            })
            self.state.statusMsg = "Folder added: " .. r.folderName
            self.state.statusColor = ui.OK
        end

    elseif actionId == "set_identity" then
        local r = adminForm(self, "SET IDENTITY", {
            { key = "name", label = "Facility Name" },
            { key = "subtitle", label = "Subtitle" },
            { key = "motto", label = "Motto" },
        })
        if r.name and #r.name > 0 then
            sendAdmin(self, "set_identity", r)
            self.state.statusMsg = "Identity updated"
            self.state.statusColor = ui.OK
        end

    elseif actionId == "set_passcode" then
        local r = adminForm(self, "SET ADMIN PASSCODE", {
            { key = "newPass", label = "New Passcode", type = "password" },
        })
        if r.newPass and #r.newPass > 0 then
            sendAdmin(self, "set_admin_passcode", { newPasscode = r.newPass })
            self.state.adminPass = r.newPass
            self.state.statusMsg = "Passcode changed"
            self.state.statusColor = ui.OK
        end
    end

    self.dirty = true
end
