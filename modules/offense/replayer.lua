-- replayer.lua — Offense Module
-- Replay captured signed messages within replay window.

local modules = require("lib.jnet_modules")
local ui = require("lib.jnet_ui")

modules.register("replayer", {
    name = "Message Replayer",
    domain = "offense",
    min_size = { w = 25, h = 6 },
    pref_size = { w = 38, h = 10 },
    peripherals = { "modem" },
    config_fields = {},

    init = function(self) self.state.buffer = {} self.state.selected = 1 end,

    render = function(self, panel)
        ui.write(panel.x, panel.y, "REPLAY BUFFER: " .. #self.state.buffer, ui.FG, ui.BG)
        for i, msg in ipairs(self.state.buffer) do
            local row = panel.y + i
            if row >= panel.y + panel.h - 1 then break end
            local prefix = (i == self.state.selected) and "> " or "  "
            ui.write(panel.x, row, prefix .. ui.truncate(msg.summary or "?", panel.w), i == self.state.selected and ui.ACCENT or ui.DIM, ui.BG)
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[ENTER]Replay [SPACE]Capture", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" then
            if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
            elseif ev[2] == keys.enter and self.state.buffer[self.state.selected] then
                local msg = self.state.buffer[self.state.selected]
                if msg.data then
                    local modem = peripheral.find("modem")
                    if modem then modem.transmit(msg.channel or 65535, msg.channel or 65535, msg.data) end
                end
            end
        elseif ev[1] == "modem_message" then
            local ch, msg = ev[3], ev[5]
            if type(msg) == "table" then
                self.state.buffer[#self.state.buffer+1] = { data = msg, channel = ch, summary = "CH:" .. ch .. " " .. (msg.type or "?") }
                if #self.state.buffer > 50 then table.remove(self.state.buffer, 1) end
                self.dirty = true
            end
        end
    end,
})
