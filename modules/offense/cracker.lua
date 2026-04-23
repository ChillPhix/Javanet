-- cracker.lua — Offense Module
-- Sends crack requests, presents puzzles for hacking.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")
local puzzle = dofile("/jnet/lib/jnet_puzzle.lua")

modules.register("cracker", {
    name = "Puzzle Cracker",
    domain = "offense",
    min_size = { w = 30, h = 10 },
    pref_size = { w = 48, h = 16 },
    peripherals = {},
    config_fields = {},

    init = function(self)
        self.state.scroll = 0
        self.state.phase = "target"
        self.state.targetId = nil
        self.state.inputBuffer = ""
        self.state.sessionToken = nil
    end,

    render = function(self, panel)
        self._panel = panel
        if self.state.phase == "target" then
            ui.write(panel.x, panel.y, "PUZZLE CRACKER", ui.FG, ui.BG)
            ui.write(panel.x, panel.y + 2, "Target ID: " .. self.state.inputBuffer .. "_", ui.ACCENT, ui.BG)
            ui.write(panel.x, panel.y + 4, "[Tap/Enter] Initiate crack", ui.DIM, ui.BG)
        elseif self.state.phase == "result" then
            if self.state.sessionToken then
                ui.write(panel.x, panel.y, "ACCESS GRANTED", ui.OK, ui.BG)
                ui.write(panel.x, panel.y + 2, "Token: " .. self.state.sessionToken, ui.ACCENT, ui.BG)
            else
                ui.write(panel.x, panel.y, "CRACK FAILED", ui.ERR, ui.BG)
            end
            ui.write(panel.x, panel.y + 4, "[BKSP] Back", ui.DIM, ui.BG)
        end
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
            if self.state.phase == "target" then
                if ev[2] == keys.enter and #self.state.inputBuffer > 0 then
                    local tid = tonumber(self.state.inputBuffer)
                    if tid then
                        self.state.targetId = tid
                        proto.sendAtk(tid, "crack_request", { resource = tid, targetName = "Target #" .. tid })
                        local tier = 2
                        local p = puzzle.generate(tier, { target = "Target #" .. tid })
                        if p then
                            local result = puzzle.run(p)
                            proto.sendAtk(tid, "crack_submit", { resource = tid, success = result.success })
                            self.state.phase = "result"
                            self.state.sessionToken = result.success and ("sess_" .. math.random(10000, 99999)) or nil
                        end
                    end
                    self.dirty = true
                elseif ev[2] == keys.backspace then
                    if #self.state.inputBuffer > 0 then self.state.inputBuffer = self.state.inputBuffer:sub(1, -2) end
                    self.dirty = true
                end
            elseif ev[2] == keys.backspace then
                self.state.phase = "target"; self.state.inputBuffer = ""; self.state.sessionToken = nil; self.dirty = true
            end
        elseif ev[1] == "char" and self.state.phase == "target" then
            if ev[2]:match("[0-9]") then self.state.inputBuffer = self.state.inputBuffer .. ev[2]; self.dirty = true end
        end
    end,
})
