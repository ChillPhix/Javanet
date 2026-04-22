-- firewall.lua — Defense Module
-- Auto-block after N failed cracks, rate limit, cooldowns.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("firewall", {
    name = "Firewall",
    domain = "defense",
    min_size = { w = 22, h = 5 },
    pref_size = { w = 30, h = 8 },
    peripherals = {},
    config_fields = {
        { key = "maxAttempts", type = "number", label = "Max attempts before block", default = 3 },
        { key = "blockDuration", type = "number", label = "Block duration (sec)", default = 300 },
    },

    init = function(self)
        self.state.blocked = {}
        self.state.attempts = {}
        self.state.totalBlocked = 0
    end,

    render = function(self, panel)
        ui.write(panel.x, panel.y, "FIREWALL", ui.FG, ui.BG)
        ui.write(panel.x, panel.y + 1, "Blocked: " .. self.state.totalBlocked, self.state.totalBlocked > 0 and ui.ERR or ui.OK, ui.BG)
        local row = panel.y + 2
        for id, info in pairs(self.state.blocked) do
            if row >= panel.y + panel.h then break end
            ui.write(panel.x, row, "  #" .. id .. " (" .. math.ceil(info.remaining or 0) .. "s)", ui.ERR, ui.BG)
            row = row + 1
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and (msg.type == "crack_request" or msg.type == "probe") then
            -- Track attempts
            local id = tostring(senderId)
            self.state.attempts[id] = (self.state.attempts[id] or 0) + 1
            if self.state.attempts[id] >= (self.config.maxAttempts or 3) then
                self.state.blocked[id] = { until_time = os.epoch("utc") / 1000 + (self.config.blockDuration or 300), remaining = self.config.blockDuration or 300 }
                self.state.totalBlocked = self.state.totalBlocked + 1
            end
            self.dirty = true
        end
    end,

    tick = function(self)
        local now = os.epoch("utc") / 1000
        for id, info in pairs(self.state.blocked) do
            info.remaining = info.until_time - now
            if info.remaining <= 0 then
                self.state.blocked[id] = nil
                self.state.attempts[id] = nil
            end
        end
    end,
})
