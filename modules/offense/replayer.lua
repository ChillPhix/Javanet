-- replayer.lua — Offense Module
-- Replay captured signed messages within replay window.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("replayer", {
    name = "Message Replayer",
    domain = "offense",
    min_size = { w = 25, h = 6 },
    pref_size = { w = 38, h = 10 },
    peripherals = { "modem" },
    config_fields = {},

    init = function(self)
        self.state.scroll = 0 self.state.buffer = {} self.state.selected = 1 end,

    render = function(self, panel)
        self._panel = panel
        ui.write(panel.x, panel.y, "REPLAY BUFFER: " .. #self.state.buffer, ui.FG, ui.BG)
        for i, msg in ipairs(self.state.buffer) do
            local row = panel.y + i
            if row >= panel.y + panel.h - 1 then break end
            local prefix = (i == self.state.selected) and "> " or "  "
            ui.write(panel.x, row, prefix .. ui.truncate(msg.summary or "?", panel.w), i == self.state.selected and ui.ACCENT or ui.DIM, ui.BG)
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[Tap/Enter]Replay [SPACE]Capture", ui.DIM, ui.BG)
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
})
