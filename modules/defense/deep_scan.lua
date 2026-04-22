-- deep_scan.lua — Defense Module
-- Detect stealth protocol (raw modem) traffic.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("deep_scan", {
    name = "Deep Scanner",
    domain = "defense",
    min_size = { w = 22, h = 5 },
    pref_size = { w = 35, h = 10 },
    peripherals = { "modem" },
    config_fields = {},

    init = function(self) self.state.detections = {} self.state.active = true end,

    render = function(self, panel)
        self._panel = panel
        ui.write(panel.x, panel.y, "DEEP SCAN " .. (self.state.active and "[ACTIVE]" or "[OFF]"), self.state.active and ui.OK or ui.DIM, ui.BG)
        local dets = self.state.detections or {}
        if #dets == 0 then ui.write(panel.x, panel.y + 1, "No stealth traffic", ui.DIM, ui.BG); return end
        local start = math.max(1, #dets - (panel.h - 2))
        for i = start, #dets do
            local row = panel.y + 1 + (i - start)
            if row >= panel.y + panel.h then break end
            ui.write(panel.x, row, ui.truncate(dets[i], panel.w), ui.WARN, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            -- Tap to toggle
            self.state.active = not self.state.active; self.dirty = true
        elseif ev[1] == "key" and ev[2] == keys.space then
            self.state.active = not self.state.active; self.dirty = true
        elseif ev[1] == "modem_message" and self.state.active then
            -- Raw modem traffic (not rednet) — stealth detected
            local ch, msg = ev[3], ev[5]
            if type(msg) == "table" and not msg.sProtocol then
                self.state.detections[#self.state.detections+1] = "CH:" .. ch .. " raw traffic detected"
                if #self.state.detections > 50 then table.remove(self.state.detections, 1) end
                self.dirty = true
            end
        end
    end,
})
