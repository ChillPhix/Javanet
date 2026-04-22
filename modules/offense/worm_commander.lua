-- worm_commander.lua — Offense Module
-- Monitor deployed worms, authorize spread with mini-puzzles.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")
local puzzle = require("lib.jnet_puzzle")

modules.register("worm_commander", {
    name = "Worm Commander",
    domain = "offense",
    min_size = { w = 25, h = 8 },
    pref_size = { w = 40, h = 14 },
    peripherals = {},
    config_fields = {},

    init = function(self)
        self.state.infections = {}
        self.state.pendingSpread = {}
        self.state.selected = 1
    end,

    render = function(self, panel)
        ui.write(panel.x, panel.y, "WORM COMMANDER", ui.FG, ui.BG)
        ui.write(panel.x, panel.y + 1, "Active: " .. #self.state.infections .. " | Pending: " .. #self.state.pendingSpread, ui.DIM, ui.BG)
        local pending = self.state.pendingSpread or {}
        if #pending == 0 then
            ui.write(panel.x, panel.y + 3, "No pending spread targets", ui.DIM, ui.BG)
        else
            for i, t in ipairs(pending) do
                local row = panel.y + 2 + i
                if row >= panel.y + panel.h - 1 then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                ui.write(panel.x, row, prefix .. "#" .. (t.id or "?") .. " " .. (t.label or ""), i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
            end
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[ENTER] Authorize (mini-puzzle)", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" then
            if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
            elseif ev[2] == keys.enter then
                local target = self.state.pendingSpread[self.state.selected]
                if target then
                    local tier = math.random(1, 2)
                    local p = puzzle.generate(tier, { target = "Spread to #" .. (target.id or "?") })
                    if p then
                        local r = puzzle.run(p)
                        if r.success then
                            self.state.infections[#self.state.infections+1] = target
                            table.remove(self.state.pendingSpread, self.state.selected)
                        end
                    end
                    self.dirty = true
                end
            end
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "worm_spread_request" and msg.payload then
            self.state.pendingSpread[#self.state.pendingSpread+1] = { id = msg.payload.targetId, label = msg.payload.label or "" }
            self.dirty = true
        end
    end,
})
