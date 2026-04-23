-- counter_hack.lua — Defense Module
-- Solve puzzle faster than attacker to lock them out.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")
local puzzle = dofile("/jnet/lib/jnet_puzzle.lua")

modules.register("counter_hack", {
    name = "Counter-Hack",
    domain = "defense",
    min_size = { w = 25, h = 8 },
    pref_size = { w = 38, h = 12 },
    peripherals = {},
    config_fields = {},

    init = function(self)
        self.state.scroll = 0 self.state.activeThreats = {} self.state.selected = 1 end,

    render = function(self, panel)
        self._panel = panel
        ui.write(panel.x, panel.y, "COUNTER-HACK", ui.FG, ui.BG)
        local threats = self.state.activeThreats or {}
        if #threats == 0 then ui.write(panel.x, panel.y + 1, "No active intrusions", ui.OK, ui.BG); return end
        for i, t in ipairs(threats) do
            local row = panel.y + i
            if row >= panel.y + panel.h - 1 then break end
            local prefix = (i == self.state.selected) and "> " or "  "
            ui.write(panel.x, row, prefix .. "#" .. t.id .. " [INTRUDING]", ui.ERR, ui.BG)
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[Tap/Enter] Counter (match tier)", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        ui.handlePanelScroll(self, ev)
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
                local t = self.state.activeThreats[self.state.selected]
                if t then
                    local tier = t.tier or 2
                    local p = puzzle.generate(tier, { target = "Counter #" .. t.id, isDefense = true })
                    if p then
                        local r = puzzle.run(p)
                        if r.success then
                            proto.sendAtk(t.id, "counter_lockout", { duration = 300 })
                            table.remove(self.state.activeThreats, self.state.selected)
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
        if type(msg) == "table" and msg.type == "crack_request" then
            local found = false
            for _, t in ipairs(self.state.activeThreats) do if t.id == senderId then found = true; break end end
            if not found then self.state.activeThreats[#self.state.activeThreats+1] = { id = senderId, tier = 2 }; self.dirty = true end
        end
    end,
})
