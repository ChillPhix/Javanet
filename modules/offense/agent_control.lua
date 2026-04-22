-- agent_control.lua — Offense Module
-- Activate/deactivate/ping deployed stealth agents.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("agent_control", {
    name = "Agent Control",
    domain = "offense",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 35, h = 10 },
    peripherals = {},
    config_fields = {},

    init = function(self) self.state.agents = {} self.state.selected = 1 end,

    render = function(self, panel)
        ui.write(panel.x, panel.y, "AGENT CONTROL", ui.FG, ui.BG)
        local agents = self.state.agents or {}
        if #agents == 0 then ui.write(panel.x, panel.y + 1, "No agents deployed", ui.DIM, ui.BG); return end
        for i, a in ipairs(agents) do
            local row = panel.y + i
            if row >= panel.y + panel.h - 1 then break end
            local prefix = (i == self.state.selected) and "> " or "  "
            local status = a.active and "[ACTIVE]" or "[DORMANT]"
            ui.write(panel.x, row, prefix .. "#" .. (a.id or "?") .. " " .. status, a.active and ui.OK or ui.DIM, ui.BG)
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[ENTER]Toggle [P]ing", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" then
            if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
            elseif ev[2] == keys.enter then
                local a = self.state.agents[self.state.selected]
                if a then a.active = not a.active; self.dirty = true end
            elseif ev[2] == keys.p then
                local a = self.state.agents[self.state.selected]
                if a then proto.sendAtk(a.id, "agent_ping", {}); self.dirty = true end
            end
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "agent_checkin" then
            local found = false
            for _, a in ipairs(self.state.agents) do if a.id == senderId then found = true; a.active = true; break end end
            if not found then self.state.agents[#self.state.agents+1] = { id = senderId, active = true } end
            self.dirty = true
        end
    end,
})
