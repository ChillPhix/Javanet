-- hmac_cracker.lua — Offense Module
-- Dictionary + brute force against captured signed messages.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("hmac_cracker", {
    name = "HMAC Cracker",
    domain = "offense",
    min_size = { w = 25, h = 6 },
    pref_size = { w = 38, h = 10 },
    peripherals = {},
    config_fields = {},

    init = function(self)
        self.state.capturedMsg = nil
        self.state.running = false
        self.state.attempts = 0
        self.state.found = nil
        self.state.dictionary = {"password", "secret", "admin", "1234", "javanet", "facility", "override", "master"}
    end,

    render = function(self, panel)
        ui.write(panel.x, panel.y, "HMAC CRACKER", ui.FG, ui.BG)
        if self.state.found then
            ui.write(panel.x, panel.y + 2, "SECRET FOUND: " .. self.state.found, ui.OK, ui.BG)
        elseif self.state.running then
            ui.write(panel.x, panel.y + 2, "Cracking... " .. self.state.attempts .. " attempts", ui.WARN, ui.BG)
        elseif self.state.capturedMsg then
            ui.write(panel.x, panel.y + 2, "Message captured. [ENTER] to crack", ui.ACCENT, ui.BG)
        else
            ui.write(panel.x, panel.y + 2, "Waiting for signed message...", ui.DIM, ui.BG)
            ui.write(panel.x, panel.y + 3, "Use Interceptor to capture", ui.DIM, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" and ev[2] == keys.enter and self.state.capturedMsg and not self.state.running then
            self.state.running = true
            self.state.attempts = 0
            -- Try dictionary
            for _, word in ipairs(self.state.dictionary) do
                self.state.attempts = self.state.attempts + 1
                -- In a real implementation, would check HMAC against captured sig
            end
            self.state.running = false
            self.dirty = true
        elseif ev[1] == "modem_message" then
            local msg = ev[5]
            if type(msg) == "table" and msg.sig then
                self.state.capturedMsg = msg
                self.dirty = true
            end
        end
    end,
})
