-- sentinel.lua — Defense Module
-- Dashboard: network health, threat level, infection status.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("sentinel", {
    name = "Network Sentinel",
    domain = "defense",
    min_size = { w = 25, h = 8 },
    pref_size = { w = 40, h = 14 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self)
        self.state.threatLevel = "LOW"
        self.state.infections = 0
        self.state.activeAttacks = 0
        self.state.blockedCount = 0
        self.state.nodes = 0
    end,

    render = function(self, panel)
        local threatColors = { LOW = ui.OK, MEDIUM = ui.WARN, HIGH = ui.ERR, CRITICAL = ui.ERR }
        ui.write(panel.x, panel.y, "NETWORK SENTINEL", ui.ACCENT, ui.BG)
        ui.write(panel.x, panel.y + 2, "Threat Level: " .. self.state.threatLevel, threatColors[self.state.threatLevel] or ui.FG, ui.BG)
        ui.write(panel.x, panel.y + 4, "Network Nodes: " .. self.state.nodes, ui.FG, ui.BG)
        ui.write(panel.x, panel.y + 5, "Active Attacks: " .. self.state.activeAttacks, self.state.activeAttacks > 0 and ui.ERR or ui.OK, ui.BG)
        ui.write(panel.x, panel.y + 6, "Infections: " .. self.state.infections, self.state.infections > 0 and ui.ERR or ui.OK, ui.BG)
        ui.write(panel.x, panel.y + 7, "Blocked: " .. self.state.blockedCount, ui.DIM, ui.BG)
        -- Threat bar
        if panel.h > 9 then
            local pct = self.state.threatLevel == "LOW" and 0.1 or (self.state.threatLevel == "MEDIUM" and 0.4 or (self.state.threatLevel == "HIGH" and 0.7 or 1.0))
            local barCol = threatColors[self.state.threatLevel] or ui.OK
            ui.progressBar(panel.x, panel.y + 9, panel.w, pct, barCol, ui.DIM, "bracket")
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" then
            if msg.type == "status_request_response" and msg.payload then
                self.state.nodes = msg.payload.terminals or 0
                self.state.infections = msg.payload.infections or 0
                -- Calculate threat level
                if self.state.infections > 2 or self.state.activeAttacks > 3 then self.state.threatLevel = "CRITICAL"
                elseif self.state.infections > 0 or self.state.activeAttacks > 1 then self.state.threatLevel = "HIGH"
                elseif self.state.activeAttacks > 0 then self.state.threatLevel = "MEDIUM"
                else self.state.threatLevel = "LOW" end
                self.dirty = true
            elseif msg.type == "crack_request" or msg.type == "probe" then
                self.state.activeAttacks = self.state.activeAttacks + 1
                self.dirty = true
            end
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "status_request", {}) end
        -- Decay attack counter
        if self.state.activeAttacks > 0 then self.state.activeAttacks = math.max(0, self.state.activeAttacks - 1) end
    end,
})
