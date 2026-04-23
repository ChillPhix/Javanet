-- siren.lua — Network Module
-- Plays configurable sound patterns via speaker peripheral.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("siren", {
    name = "Siren / Alarm",
    domain = "network",
    min_size = { w = 15, h = 4 },
    pref_size = { w = 22, h = 6 },
    peripherals = { "speaker" },
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "redstoneSide", type = "string", label = "Redstone out side", default = "" },
    },

    init = function(self)
        self.state.scroll = 0 self.state.active = false self.state.pattern = "alert" end,

    render = function(self, panel)
        self._panel = panel
        local cy = panel.y + math.floor(panel.h / 2)
        if self.state.active then
            ui.write(panel.x, cy, ui.pad("!! SIREN ACTIVE !!", panel.w, " ", "center"), ui.ERR, ui.BG)
        else
            ui.write(panel.x, cy, ui.pad("Siren: Standby", panel.w, " ", "center"), ui.DIM, ui.BG)
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "facility_update" then
            local p = msg.payload or {}
            if p.type == "state" then
                self.state.active = (p.state == "emergency" or p.state == "lockdown")
                if self.state.active then
                    local side = self.config.redstoneSide
                    if side and #side > 0 then redstone.setOutput(side, true) end
                else
                    local side = self.config.redstoneSide
                    if side and #side > 0 then redstone.setOutput(side, false) end
                end
                self.dirty = true
            end
        end
    end,

    tick = function(self)
        if self.state.active then
            local speaker = peripheral.find("speaker")
            if speaker then
                pcall(function() speaker.playNote("bell", 3, 18) end)
            end
        end
    end,

    cleanup = function(self)
        local side = self.config.redstoneSide
        if side and #side > 0 then redstone.setOutput(side, false) end
    end,
})
