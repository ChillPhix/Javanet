-- honeypot.lua — Defense Module
-- Makes terminal look vulnerable. Logs everything, silent alarm.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("honeypot", {
    name = "Honeypot",
    domain = "defense",
    min_size = { w = 20, h = 5 },
    pref_size = { w = 30, h = 8 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "fakeName", type = "string", label = "Fake terminal name", default = "ADMIN_CONSOLE" },
    },

    init = function(self)
        self.state.scroll = 0 self.state.trapped = {} self.state.trapCount = 0 end,

    render = function(self, panel)
        self._panel = panel
        ui.write(panel.x, panel.y, "HONEYPOT MODE", ui.WARN, ui.BG)
        ui.write(panel.x, panel.y + 1, "Disguised as: " .. (self.config.fakeName or "?"), ui.DIM, ui.BG)
        ui.write(panel.x, panel.y + 2, "Trapped: " .. self.state.trapCount, self.state.trapCount > 0 and ui.OK or ui.DIM, ui.BG)
        for i, t in ipairs(self.state.trapped or {}) do
            local row = panel.y + 3 + i
            if row >= panel.y + panel.h then break end
            ui.write(panel.x, row, "  #" .. t.id .. " at " .. (t.time or "?"), ui.OK, ui.BG)
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and (msg.type == "probe" or msg.type == "crack_request") then
            self.state.trapped[#self.state.trapped+1] = { id = senderId, time = os.date("%H:%M"), type = msg.type }
            self.state.trapCount = self.state.trapCount + 1
            -- Silent alarm to mainframe
            local mfId = self.config.mainframeId
            if mfId then
                proto.send(tonumber(mfId), "facility_command", { action = "set_state", state = "alert" })
            end
            self.dirty = true
            -- Respond slowly to waste attacker time
            sleep(2)
        end
    end,
})
