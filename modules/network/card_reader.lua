-- card_reader.lua — Network Module
-- Reads floppy disk ID cards and sends auth to mainframe.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("card_reader", {
    name = "Card Reader",
    domain = "network",
    min_size = { w = 18, h = 5 },
    pref_size = { w = 28, h = 8 },
    peripherals = { "drive" },
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "zone", type = "string", label = "Zone" },
        { key = "minClearance", type = "number", label = "Min clearance", default = 5 },
        { key = "openDuration", type = "number", label = "Door open time (sec)", default = 3 },
    },

    init = function(self)
        self.state.lastResult = nil
        self.state.lastName = nil
        self.state.showResult = false
        self.state.resultTimer = nil
    end,

    render = function(self, panel)
        local cx = panel.x + math.floor(panel.w / 2)
        local cy = panel.y + 1

        local drive = peripheral.find("drive")
        local hasDisk = drive and drive.isDiskPresent()

        if self.state.showResult then
            if self.state.lastResult == "granted" then
                ui.centerWrite(cy, "ACCESS GRANTED", ui.OK, ui.BG)
                ui.centerWrite(cy + 1, self.state.lastName or "", ui.ACCENT, ui.BG)
                if self.state.clearanceName then
                    ui.centerWrite(cy + 2, self.state.clearanceName, ui.DIM, ui.BG)
                end
            else
                ui.centerWrite(cy, "ACCESS DENIED", ui.ERR, ui.BG)
                ui.centerWrite(cy + 1, self.state.lastReason or "", ui.DIM, ui.BG)
            end
        elseif hasDisk then
            ui.centerWrite(cy + 1, "READING CARD...", ui.WARN, ui.BG)
        else
            ui.centerWrite(cy, "INSERT ID CARD", ui.DIM, ui.BG)
            local zone = self.config.zone or ""
            if #zone > 0 then
                ui.centerWrite(cy + 2, "Zone: " .. zone, ui.DIM, ui.BG)
            end
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "disk" then
            -- Card inserted
            local drive = peripheral.find("drive")
            if drive and drive.isDiskPresent() then
                local diskId = drive.getDiskID()
                if diskId then
                    local mfId = self.config.mainframeId
                    if mfId then
                        local response = proto.request(tonumber(mfId), "auth_request", {
                            diskId = diskId,
                        }, 5)
                        if response and response.payload then
                            local r = response.payload
                            if r.granted then
                                self.state.lastResult = "granted"
                                self.state.lastName = r.name
                                self.state.clearanceName = r.clearanceName
                                -- Trigger door lock module via state
                                self.state.doorOpen = true
                            else
                                self.state.lastResult = "denied"
                                self.state.lastReason = r.reason or "denied"
                            end
                        else
                            self.state.lastResult = "denied"
                            self.state.lastReason = "No response"
                        end
                        self.state.showResult = true
                        self.dirty = true
                    end
                end
            end
        elseif ev[1] == "disk_eject" then
            self.state.showResult = false
            self.state.doorOpen = false
            self.dirty = true
        end
        return nil
    end,

    tick = function(self)
        -- Auto-clear result after display time
    end,
})
