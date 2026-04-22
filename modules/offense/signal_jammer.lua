-- signal_jammer.lua — Offense Module
-- Flood raw modem traffic to cause timeouts.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("signal_jammer", {
    name = "Signal Jammer",
    domain = "offense",
    min_size = { w = 20, h = 4 },
    pref_size = { w = 28, h = 6 },
    peripherals = { "modem" },
    config_fields = {
        { key = "channel", type = "number", label = "Target channel", default = 65535 },
    },

    init = function(self) self.state.active = false self.state.sent = 0 end,

    render = function(self, panel)
        local cy = panel.y + math.floor(panel.h / 2)
        if self.state.active then
            ui.write(panel.x, cy, ui.pad("!! JAMMING !!", panel.w, " ", "center"), ui.ERR, ui.BG)
            ui.write(panel.x, cy + 1, ui.pad("Packets: " .. self.state.sent, panel.w, " ", "center"), ui.DIM, ui.BG)
        else
            ui.write(panel.x, cy, ui.pad("[SPACE] Start Jammer", panel.w, " ", "center"), ui.WARN, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" and ev[2] == keys.space then
            self.state.active = not self.state.active
            self.state.sent = 0
            self.dirty = true
        end
    end,

    tick = function(self)
        if self.state.active then
            local modem = peripheral.find("modem")
            if modem then
                local ch = self.config.channel or 65535
                for i = 1, 5 do
                    modem.transmit(ch, ch, { junk = math.random(0, 0xFFFFFF), ts = os.epoch("utc") })
                    self.state.sent = self.state.sent + 1
                end
            end
        end
    end,
})
