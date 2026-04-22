-- keylogger.lua — Offense Module
-- Deploy fake door terminal that captures card swipes.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("keylogger", {
    name = "Keylogger",
    domain = "offense",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 30, h = 10 },
    peripherals = { "drive" },
    config_fields = {
        { key = "fakeZone", type = "string", label = "Fake zone name", default = "OFFICE" },
    },

    init = function(self)
        self.state.captures = {}
        self.state.active = true
        self.state.showCaptures = false
    end,

    render = function(self, panel)
        if self.state.showCaptures then
            ui.write(panel.x, panel.y, "CAPTURED: " .. #self.state.captures, ui.FG, ui.BG)
            for i, c in ipairs(self.state.captures) do
                local row = panel.y + i
                if row >= panel.y + panel.h then break end
                ui.write(panel.x, row, "DiskID:" .. c.diskId, ui.ACCENT, ui.BG)
            end
            ui.write(panel.x, panel.y + panel.h - 1, "[F1] Hide captures", ui.DIM, ui.BG)
        else
            -- Looks like a normal door terminal
            local cy = panel.y + math.floor(panel.h / 2)
            ui.write(panel.x, cy, ui.pad("INSERT ID CARD", panel.w, " ", "center"), ui.DIM, ui.BG)
            ui.write(panel.x, cy + 1, ui.pad("Zone: " .. (self.config.fakeZone or ""), panel.w, " ", "center"), ui.DIM, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "disk" then
            local drive = peripheral.find("drive")
            if drive and drive.isDiskPresent() then
                local diskId = drive.getDiskID()
                self.state.captures[#self.state.captures+1] = { diskId = diskId, time = os.epoch("utc") }
                self.dirty = true
            end
        elseif ev[1] == "key" and ev[2] == keys.f1 then
            self.state.showCaptures = not self.state.showCaptures
            self.dirty = true
        end
    end,
})
