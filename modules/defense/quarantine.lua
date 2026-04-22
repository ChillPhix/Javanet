-- quarantine.lua — Defense Module
-- Isolate compromised computers from the network.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("quarantine", {
    name = "Quarantine",
    domain = "defense",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 30, h = 10 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self) self.state.quarantined = {} self.state.selected = 1 self.state.inputBuffer = "" end,

    render = function(self, panel)
        ui.write(panel.x, panel.y, "QUARANTINE ZONE", ui.FG, ui.BG)
        local q = self.state.quarantined or {}
        if #q == 0 then ui.write(panel.x, panel.y + 1, "No quarantined nodes", ui.OK, ui.BG)
        else
            for i, id in ipairs(q) do
                local row = panel.y + i
                if row >= panel.y + panel.h - 2 then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                ui.write(panel.x, row, prefix .. "#" .. id .. " [ISOLATED]", ui.ERR, ui.BG)
            end
        end
        ui.write(panel.x, panel.y + panel.h - 2, "Add: " .. self.state.inputBuffer .. "_", ui.DIM, ui.BG)
        ui.write(panel.x, panel.y + panel.h - 1, "[ENTER]Add [D]elease", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" then
            if ev[2] == keys.enter and #self.state.inputBuffer > 0 then
                local id = tonumber(self.state.inputBuffer)
                if id then self.state.quarantined[#self.state.quarantined+1] = id end
                self.state.inputBuffer = ""
                self.dirty = true
            elseif ev[2] == keys.d then
                if self.state.quarantined[self.state.selected] then
                    table.remove(self.state.quarantined, self.state.selected)
                    self.dirty = true
                end
            elseif ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
            elseif ev[2] == keys.backspace then
                if #self.state.inputBuffer > 0 then self.state.inputBuffer = self.state.inputBuffer:sub(1, -2); self.dirty = true end
            end
        elseif ev[1] == "char" and ev[2]:match("[0-9]") then
            self.state.inputBuffer = self.state.inputBuffer .. ev[2]; self.dirty = true
        end
    end,
})
