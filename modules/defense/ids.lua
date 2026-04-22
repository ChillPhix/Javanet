-- ids.lua — Defense Module
-- Intrusion Detection System. Alerts on probes, cracks, forged cards.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("ids", {
    name = "Intrusion Detection",
    domain = "defense",
    min_size = { w = 25, h = 6 },
    pref_size = { w = 40, h = 12 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self) self.state.alerts = {} self.state.alertCount = 0 end,

    render = function(self, panel)
        self._panel = panel
        local col = self.state.alertCount > 0 and ui.ERR or ui.OK
        ui.write(panel.x, panel.y, "IDS: " .. self.state.alertCount .. " alerts", col, ui.BG)
        local alerts = self.state.alerts or {}
        local start = math.max(1, #alerts - (panel.h - 2))
        for i = start, #alerts do
            local row = panel.y + 1 + (i - start)
            if row >= panel.y + panel.h then break end
            ui.write(panel.x, row, ui.truncate(alerts[i], panel.w), ui.WARN, ui.BG)
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" then
            local alert = nil
            if msg.type == "probe" then alert = "PROBE from #" .. senderId
            elseif msg.type == "crack_request" then alert = "CRACK ATTEMPT from #" .. senderId
            elseif msg.type == "deploy" then alert = "DEPLOY from #" .. senderId .. " type:" .. ((msg.payload or {}).deployType or "?")
            elseif msg.type == "facility_update" and (msg.payload or {}).type == "intrusion" then alert = "INTRUSION on #" .. ((msg.payload or {}).resource or "?")
            end
            if alert then
                self.state.alerts[#self.state.alerts+1] = os.date("%H:%M") .. " " .. alert
                self.state.alertCount = self.state.alertCount + 1
                if #self.state.alerts > 100 then table.remove(self.state.alerts, 1) end
                self.dirty = true
            end
        end
    end,
})
