-- admin_panel.lua — Network Module
-- Full admin: manage personnel, doors, entities, zones, passcodes, identity.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("admin_panel", {
    name = "Admin Panel",
    domain = "network",
    min_size = { w = 30, h = 10 },
    pref_size = { w = 48, h = 16 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self)
        self.state.authenticated = false
        self.state.adminPass = nil
        self.state.view = "menu"
        self.state.selected = 1
        self.state.menuItems = {
            "Personnel Management", "Zone Management", "Entity Management",
            "Door Registration", "Card Management", "Security Tiers",
            "Archive Management", "Identity Settings", "Passcode Settings",
            "View Pending Terminals", "View Infections", "View Log",
        }
    end,

    render = function(self, panel)
        if not self.state.authenticated then
            ui.write(panel.x, panel.y + math.floor(panel.h/2), "ADMIN LOGIN REQUIRED", ui.WARN, ui.BG)
            ui.write(panel.x, panel.y + math.floor(panel.h/2) + 1, "Press ENTER", ui.DIM, ui.BG)
            return
        end
        if self.state.view == "menu" then
            for i, item in ipairs(self.state.menuItems) do
                local row = panel.y + i - 1
                if row >= panel.y + panel.h then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                ui.write(panel.x, row, prefix .. item, i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
            end
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" then
            if not self.state.authenticated and ev[2] == keys.enter then
                ui.clear()
                ui.header(ui.facilityName, "ADMIN LOGIN")
                local pass = ui.passwordPrompt(5, "Admin passcode: ")
                self.state.adminPass = pass
                self.state.authenticated = true
                self.dirty = true
                return
            end
            if self.state.view == "menu" then
                if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
                elseif ev[2] == keys.down then self.state.selected = math.min(#self.state.menuItems, self.state.selected + 1); self.dirty = true
                elseif ev[2] == keys.enter then
                    local mfId = self.config.mainframeId
                    local pass = self.state.adminPass
                    local sel = self.state.selected
                    if sel == 1 and mfId then
                        -- Personnel: interactive add
                        ui.clear()
                        ui.header(ui.facilityName, "ADD PERSONNEL")
                        local name = ui.prompt(4, "Name: ")
                        local cl = tonumber(ui.prompt(6, "Clearance: ")) or 5
                        local dept = ui.prompt(8, "Department: ")
                        if name and #name > 0 then
                            proto.send(tonumber(mfId), "admin_command", { passcode = pass, command = "add_person", name = name, clearance = cl, department = dept })
                        end
                        self.dirty = true
                    elseif sel == 2 and mfId then
                        ui.clear()
                        ui.header(ui.facilityName, "ADD ZONE")
                        local zone = ui.prompt(4, "Zone name: ")
                        if zone and #zone > 0 then
                            proto.send(tonumber(mfId), "admin_command", { passcode = pass, command = "add_zone", zone = zone })
                        end
                        self.dirty = true
                    elseif sel == 3 and mfId then
                        ui.clear()
                        ui.header(ui.facilityName, "ADD ENTITY")
                        local eid = ui.prompt(4, "Entity ID: ")
                        local ename = ui.prompt(5, "Name: ")
                        local eclass = ui.prompt(6, "Class: ")
                        local ezone = ui.prompt(7, "Zone: ")
                        local edesc = ui.prompt(8, "Description: ")
                        if eid and #eid > 0 then
                            proto.send(tonumber(mfId), "admin_command", { passcode = pass, command = "add_entity", entityId = eid, name = ename, class = eclass, zone = ezone, description = edesc })
                        end
                        self.dirty = true
                    elseif sel == 4 and mfId then
                        ui.clear()
                        ui.header(ui.facilityName, "REGISTER DOOR")
                        local compId = tonumber(ui.prompt(4, "Computer ID: "))
                        local zone = ui.prompt(5, "Zone: ")
                        local minCl = tonumber(ui.prompt(6, "Min clearance: ")) or 5
                        local tier = tonumber(ui.prompt(7, "Security tier (1-5): ")) or 2
                        if compId then
                            proto.send(tonumber(mfId), "admin_command", { passcode = pass, command = "register_door", compId = compId, zone = zone, minClearance = minCl, securityTier = tier })
                        end
                        self.dirty = true
                    elseif sel == 6 and mfId then
                        ui.clear()
                        ui.header(ui.facilityName, "SET SECURITY TIER")
                        local res = ui.prompt(4, "Resource/Computer ID: ")
                        local tier = tonumber(ui.prompt(5, "Tier (1-5): ")) or 2
                        if res then proto.send(tonumber(mfId), "admin_command", { passcode = pass, command = "set_security_tier", resource = res, tier = tier }) end
                        self.dirty = true
                    elseif sel == 7 and mfId then
                        ui.clear()
                        ui.header(ui.facilityName, "ADD ARCHIVE FOLDER")
                        local fname = ui.prompt(4, "Folder name: ")
                        local fcl = tonumber(ui.prompt(5, "Min clearance: ")) or 5
                        if fname then proto.send(tonumber(mfId), "admin_command", { passcode = pass, command = "archive_add_folder", folderName = fname, minClearance = fcl }) end
                        self.dirty = true
                    end
                elseif ev[2] == keys.backspace then
                    self.state.authenticated = false
                    self.dirty = true
                end
            end
        end
    end,
})
