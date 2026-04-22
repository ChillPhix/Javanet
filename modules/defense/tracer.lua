-- tracer.lua — Defense Module
-- Solve counter-puzzle to reveal attacker computer ID.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")
local puzzle = require("lib.jnet_puzzle")

modules.register("tracer", {
    name = "Tracer",
    domain = "defense",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 35, h = 10 },
    peripherals = {},
    config_fields = {},

    init = function(self)
        self.state.attackers = {}
        self.state.selected = 1
        self.state.traced = {}
    end,

    render = function(self, panel)
        ui.write(panel.x, panel.y, "TRACER", ui.FG, ui.BG)
        local attackers = self.state.attackers or {}
        if #attackers == 0 then ui.write(panel.x, panel.y + 1, "No active threats", ui.DIM, ui.BG); return end
        for i, a in ipairs(attackers) do
            local row = panel.y + i
            if row >= panel.y + panel.h - 1 then break end
            local prefix = (i == self.state.selected) and "> " or "  "
            local traced = self.state.traced[tostring(a.id)]
            local info = "#" .. a.id .. (traced and (" [TRACED: " .. traced .. "]") or " [UNKNOWN]")
            ui.write(panel.x, row, prefix .. ui.truncate(info, panel.w), i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[ENTER] Trace (T2 puzzle)", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" then
            if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
            elseif ev[2] == keys.enter then
                local a = self.state.attackers[self.state.selected]
                if a then
                    local p = puzzle.generate(2, { target = "Trace #" .. a.id, isDefense = true })
                    if p then
                        local r = puzzle.run(p)
                        if r.success then
                            self.state.traced[tostring(a.id)] = "ID#" .. a.id .. " " .. (os.getComputerLabel() or "")
                        end
                    end
                    self.dirty = true
                end
            end
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and (msg.type == "crack_request" or msg.type == "probe") then
            local found = false
            for _, a in ipairs(self.state.attackers) do if a.id == senderId then found = true; break end end
            if not found then self.state.attackers[#self.state.attackers+1] = { id = senderId }; self.dirty = true end
        end
    end,
})
