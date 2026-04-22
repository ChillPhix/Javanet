-- radio.lua — Network Module
-- Broadcast/listen on open radio channels.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("radio", {
    name = "Radio",
    domain = "network",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 35, h = 12 },
    peripherals = {},
    config_fields = {
        { key = "channel", type = "number", label = "Channel", default = 100 },
        { key = "callsign", type = "string", label = "Callsign", default = "STATION" },
    },

    init = function(self) self.state.messages = {} self.state.inputBuffer = "" end,

    render = function(self, panel)
        self._panel = panel
        ui.write(panel.x, panel.y, "CH:" .. (self.config.channel or 100) .. " [" .. (self.config.callsign or "?") .. "]", ui.ACCENT, ui.BG)
        local msgs = self.state.messages or {}
        local start = math.max(1, #msgs - panel.h + 3)
        for i = start, #msgs do
            local row = panel.y + 1 + (i - start)
            if row >= panel.y + panel.h - 1 then break end
            ui.write(panel.x, row, ui.truncate(msgs[i], panel.w), ui.DIM, ui.BG)
        end
        ui.write(panel.x, panel.y + panel.h - 1, "> " .. self.state.inputBuffer .. "_", ui.FG, ui.BG)
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
            if ev[2] == keys.enter and #self.state.inputBuffer > 0 then
                local modem = peripheral.find("modem")
                if modem then
                    local ch = self.config.channel or 100
                    if not modem.isOpen(ch) then modem.open(ch) end
                    modem.transmit(ch, ch, { type = "radio", callsign = self.config.callsign, msg = self.state.inputBuffer })
                end
                self.state.messages[#self.state.messages+1] = "[" .. (self.config.callsign or "YOU") .. "] " .. self.state.inputBuffer
                self.state.inputBuffer = ""
                self.dirty = true
            elseif ev[2] == keys.backspace then
                if #self.state.inputBuffer > 0 then self.state.inputBuffer = self.state.inputBuffer:sub(1, -2); self.dirty = true end
            end
        elseif ev[1] == "char" then
            self.state.inputBuffer = self.state.inputBuffer .. ev[2]
            self.dirty = true
        elseif ev[1] == "modem_message" then
            local ch, rch, msg = ev[3], ev[4], ev[5]
            if ch == (self.config.channel or 100) and type(msg) == "table" and msg.type == "radio" then
                self.state.messages[#self.state.messages+1] = "[" .. (msg.callsign or "???") .. "] " .. (msg.msg or "")
                if #self.state.messages > 100 then table.remove(self.state.messages, 1) end
                self.dirty = true
            end
        end
    end,

    init = function(self)
        self.state.messages = {}
        self.state.inputBuffer = ""
        local modem = peripheral.find("modem")
        if modem then
            local ch = self.config.channel or 100
            if not modem.isOpen(ch) then modem.open(ch) end
        end
    end,
})
