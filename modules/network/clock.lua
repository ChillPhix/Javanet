-- clock.lua — Network Module
-- Shows current game time / real time.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("clock", {
    name = "Clock",
    domain = "network",
    min_size = { w = 12, h = 3 },
    pref_size = { w = 18, h = 5 },
    peripherals = {},
    config_fields = {},

    init = function(self) end,

    render = function(self, panel)
        self._panel = panel
        local time = textutils.formatTime(os.time(), true)
        local day = os.day()
        ui.write(panel.x + math.floor((panel.w - #time) / 2), panel.y + math.floor(panel.h / 2), time, ui.ACCENT, ui.BG)
        local dayStr = "Day " .. day
        ui.write(panel.x + math.floor((panel.w - #dayStr) / 2), panel.y + math.floor(panel.h / 2) + 1, dayStr, ui.DIM, ui.BG)
    end,

    tick = function(self) self.dirty = true end,
})
