-- panic_button.lua — Network Module
-- One-click emergency alert with optional redstone trigger.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("panic_button", {
    name = "Panic Button",
    domain = "network",
    min_size = { w = 15, h = 4 },
    pref_size = { w = 20, h = 6 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "redstoneSide", type = "string", label = "Redstone trigger side", default = "" },
    },

    init = function(self)
        self.state.scroll = 0 self.state.triggered = false end,

    render = function(self, panel)
        self._panel = panel
        local cy = panel.y + math.floor(panel.h / 2)
        if self.state.triggered then
            ui.write(panel.x, cy, ui.pad("!! ALERT SENT !!", panel.w, " ", "center"), ui.ERR, ui.BG)
        else
            ui.write(panel.x, cy, ui.pad("[PANIC BUTTON]", panel.w, " ", "center"), ui.WARN, ui.BG)
            ui.write(panel.x, cy + 1, ui.pad("[ TAP TO TRIGGER ]", panel.w, " ", "center"), ui.DIM, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        ui.handlePanelScroll(self, ev)
        if (ev[1] == "mouse_click" or ev[1] == "monitor_touch") and not self.state.triggered then
            self.state.triggered = true
            local mfId = self.config.mainframeId
            if mfId then
                proto.send(tonumber(mfId), "facility_command", { action = "set_state", state = "emergency" })
            end
            self.dirty = true
            os.startTimer(5)
        elseif ev[1] == "key" and ev[2] == keys.enter and not self.state.triggered then
            self.state.triggered = true
            local mfId = self.config.mainframeId
            if mfId then
                proto.send(tonumber(mfId), "facility_command", { action = "set_state", state = "emergency" })
            end
            self.dirty = true
            os.startTimer(5)
        elseif ev[1] == "redstone" then
            local side = self.config.redstoneSide
            if side and #side > 0 and redstone.getInput(side) then
                self.state.triggered = true
                local mfId = self.config.mainframeId
                if mfId then proto.send(tonumber(mfId), "facility_command", { action = "set_state", state = "emergency" }) end
                self.dirty = true
            end
        elseif ev[1] == "timer" then
            self.state.triggered = false
            self.dirty = true
        end
    end,
})
