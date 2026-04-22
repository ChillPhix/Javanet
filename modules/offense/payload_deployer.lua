-- payload_deployer.lua — Offense Module
-- Push lockout/worm/backdoor/agent to compromised targets.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("payload_deployer", {
    name = "Payload Deployer",
    domain = "offense",
    min_size = { w = 25, h = 6 },
    pref_size = { w = 35, h = 10 },
    peripherals = {},
    config_fields = {},

    init = function(self)
        self.state.payloads = {"lockout", "worm", "backdoor", "agent"}
        self.state.selected = 1
        self.state.targetBuffer = ""
        self.state.phase = "target"
    end,

    render = function(self, panel)
        if self.state.phase == "target" then
            ui.write(panel.x, panel.y, "PAYLOAD DEPLOYER", ui.FG, ui.BG)
            ui.write(panel.x, panel.y + 2, "Target ID: " .. self.state.targetBuffer .. "_", ui.ACCENT, ui.BG)
        elseif self.state.phase == "select" then
            ui.write(panel.x, panel.y, "Select payload:", ui.FG, ui.BG)
            for i, p in ipairs(self.state.payloads) do
                local row = panel.y + i
                if row >= panel.y + panel.h then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                ui.write(panel.x, row, prefix .. p:upper(), i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
            end
        elseif self.state.phase == "deployed" then
            ui.write(panel.x, panel.y, "PAYLOAD DEPLOYED", ui.OK, ui.BG)
            ui.write(panel.x, panel.y + 2, "[BKSP] Back", ui.DIM, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" then
            if self.state.phase == "target" then
                if ev[2] == keys.enter and #self.state.targetBuffer > 0 then
                    self.state.phase = "select"; self.dirty = true
                elseif ev[2] == keys.backspace then
                    if #self.state.targetBuffer > 0 then self.state.targetBuffer = self.state.targetBuffer:sub(1, -2); self.dirty = true end
                end
            elseif self.state.phase == "select" then
                if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
                elseif ev[2] == keys.down then self.state.selected = math.min(#self.state.payloads, self.state.selected + 1); self.dirty = true
                elseif ev[2] == keys.enter then
                    local tid = tonumber(self.state.targetBuffer)
                    if tid then
                        proto.sendAtk(tid, "deploy", { deployType = self.state.payloads[self.state.selected], targetComp = tid })
                    end
                    self.state.phase = "deployed"; self.dirty = true
                elseif ev[2] == keys.backspace then self.state.phase = "target"; self.dirty = true end
            elseif ev[2] == keys.backspace then
                self.state.phase = "target"; self.state.targetBuffer = ""; self.dirty = true
            end
        elseif ev[1] == "char" and self.state.phase == "target" then
            if ev[2]:match("[0-9]") then self.state.targetBuffer = self.state.targetBuffer .. ev[2]; self.dirty = true end
        end
    end,
})
