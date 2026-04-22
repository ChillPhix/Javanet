-- interceptor.lua — Offense Module
-- Raw modem sniffer, captures all traffic.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("interceptor", {
    name = "Traffic Interceptor",
    domain = "offense",
    min_size = { w = 30, h = 8 },
    pref_size = { w = 48, h = 14 },
    peripherals = { "modem" },
    config_fields = {
        { key = "channels", type = "string", label = "Channels (comma-sep)", default = "1,2,65535" },
    },

    init = function(self)
        self.state.captures = {}
        self.state.active = false
        self.state.captureCount = 0
    end,

    render = function(self, panel)
        self._panel = panel
        local st = self.state.active and "[LISTENING]" or "[STOPPED]"
        ui.write(panel.x, panel.y, "INTERCEPTOR " .. st, self.state.active and ui.OK or ui.DIM, ui.BG)
        ui.write(panel.x, panel.y + 1, "Captured: " .. self.state.captureCount, ui.DIM, ui.BG)
        local caps = self.state.captures or {}
        local start = math.max(1, #caps - (panel.h - 3))
        for i = start, #caps do
            local row = panel.y + 2 + (i - start)
            if row >= panel.y + panel.h then break end
            ui.write(panel.x, row, ui.truncate(caps[i], panel.w), ui.DIM, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" or (ev[1] == "key" and ev[2] == keys.space) then
            self.state.active = not self.state.active
            if self.state.active then
                local modem = peripheral.find("modem")
                if modem then
                    for ch in (self.config.channels or "1,2,65535"):gmatch("(%d+)") do
                        local c = tonumber(ch)
                        if c and not modem.isOpen(c) then modem.open(c) end
                    end
                end
            end
            self.dirty = true
        elseif ev[1] == "modem_message" and self.state.active then
            local ch, msg = ev[3], ev[5]
            self.state.captures[#self.state.captures+1] = "CH:" .. ch .. " " .. textutils.serialize(msg):sub(1, 60)
            self.state.captureCount = self.state.captureCount + 1
            if #self.state.captures > 200 then table.remove(self.state.captures, 1) end
            self.dirty = true
        end
    end,
})
