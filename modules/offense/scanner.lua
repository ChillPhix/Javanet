-- scanner.lua — Offense Module
-- Passive/active scan for nearby Javanet computers.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("scanner", {
    name = "Network Scanner",
    domain = "offense",
    min_size = { w = 25, h = 6 },
    pref_size = { w = 38, h = 12 },
    peripherals = { "modem" },
    config_fields = {},

    init = function(self)
        self.state.scroll = 0 self.state.targets = {} self.state.selected = 1 self.state.scanning = false end,

    render = function(self, panel)
        self._panel = panel
        ui.write(panel.x, panel.y, "NETWORK SCANNER", ui.FG, ui.BG)
        local status = self.state.scanning and "[SCAN]" or "[IDLE]"
        ui.write(panel.x + panel.w - 7, panel.y, status, self.state.scanning and ui.WARN or ui.DIM, ui.BG)
        local targets = self.state.targets or {}
        if #targets == 0 then ui.write(panel.x, panel.y + 1, "No targets", ui.DIM, ui.BG)
        else
            for i, t in ipairs(targets) do
                local row = panel.y + i
                if row >= panel.y + panel.h - 1 then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                ui.write(panel.x, row, prefix .. ui.truncate("#" .. t.id .. " " .. (t.name or "?"), panel.w), i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
            end
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[S]can [ENTER]Profile", ui.DIM, ui.BG)
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
            if ev[2] == keys.s then
                self.state.scanning = true
                self.dirty = true
                proto.broadcastAtk("probe", { scanner = os.getComputerID() })
                os.startTimer(3)
            elseif ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
            end
        elseif ev[1] == "timer" then self.state.scanning = false; self.dirty = true end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "probe_response" and msg.payload then
            local found = false
            for _, t in ipairs(self.state.targets) do if t.id == senderId then found = true; break end end
            if not found then
                self.state.targets[#self.state.targets+1] = { id = senderId, name = msg.payload.name or "?" }
                self.dirty = true
            end
        end
    end,
})
