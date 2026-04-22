-- card_issuer.lua — Network Module
-- Passcode-gated ID card creation.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("card_issuer", {
    name = "Card Issuer",
    domain = "network",
    min_size = { w = 25, h = 8 },
    pref_size = { w = 35, h = 12 },
    peripherals = { "drive" },
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self)
        self.state.phase = "idle"
        self.state.message = ""
    end,

    render = function(self, panel)
        local cy = panel.y + 1
        local drive = peripheral.find("drive")
        local hasDisk = drive and drive.isDiskPresent()
        if self.state.phase == "idle" then
            if hasDisk then
                ui.write(panel.x, cy, "Card detected.", ui.OK, ui.BG)
                ui.write(panel.x, cy+1, "Press ENTER to issue.", ui.DIM, ui.BG)
            else
                ui.write(panel.x, cy, "Insert blank card", ui.DIM, ui.BG)
            end
        elseif self.state.phase == "done" then
            ui.write(panel.x, cy, self.state.message, ui.OK, ui.BG)
        elseif self.state.phase == "error" then
            ui.write(panel.x, cy, self.state.message, ui.ERR, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" and ev[2] == keys.enter and self.state.phase == "idle" then
            local drive = peripheral.find("drive")
            if drive and drive.isDiskPresent() then
                ui.clear()
                ui.header(ui.facilityName, "CARD ISSUER")
                local passcode = ui.passwordPrompt(4, "Issuer passcode: ")
                local name = ui.prompt(6, "Player name: ")
                local clearance = tonumber(ui.prompt(8, "Clearance level: ")) or 5
                local department = ui.prompt(10, "Department: ")
                local diskId = drive.getDiskID()
                if diskId and name and #name > 0 then
                    local mfId = self.config.mainframeId
                    if mfId then
                        local resp = proto.request(tonumber(mfId), "issue_request", {
                            passcode = passcode, diskId = diskId,
                            name = name, clearance = clearance,
                            department = department or "General",
                        }, 5)
                        if resp and resp.payload and resp.payload.success then
                            self.state.phase = "done"
                            self.state.message = "Issued to: " .. name
                        else
                            self.state.phase = "error"
                            self.state.message = "Failed"
                        end
                    end
                end
                self.dirty = true
            end
        elseif ev[1] == "disk_eject" then
            self.state.phase = "idle"
            self.dirty = true
        end
    end,
})
