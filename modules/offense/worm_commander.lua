-- worm_commander.lua — Offense Module
-- Monitor deployed worms, authorize spread with mini-puzzles.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")
local puzzle = dofile("/jnet/lib/jnet_puzzle.lua")

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
        self._panel = panel
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
        ui.write(panel.x, panel.y + panel.h - 1, "[Tap/Enter] Authorize (mini-puzzle)", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local cy = ev[1] == "monitor_touch" and ev[4] or ev[4]
            if self._panel then
                local relY = cy - self._panel.y + 1
                if relY >= 1 then
                    self.state.selected = relY
                    self.dirty = true
                end
            end
        elseif ev[1] == "key" then
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

        elseif ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local cy = ev[1] == "monitor_touch" and ev[4] or ev[4]
            local cx = ev[1] == "monitor_touch" and ev[3] or ev[3]
            -- Click on list items to select and activate
            if self._panel then
                local relY = cy - self._panel.y
                if relY >= 1 and relY <= self._panel.h then
                    self.state.selected = relY
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
