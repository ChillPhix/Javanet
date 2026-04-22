-- full_log.lua — Network Module
-- Scrollable full audit log with filtering and search.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("full_log", {
    name = "Full Log Viewer",
    domain = "network",
    min_size = { w = 30, h = 8 },
    pref_size = { w = 48, h = 16 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self)
        self.state.logLines = {}
        self.state.scroll = 0
        self.state.filter = ""
    end,

    render = function(self, panel)
        self._panel = panel
        local lines = self.state.logLines or {}
        local filtered = lines
        if self.state.filter and #self.state.filter > 0 then
            filtered = {}
            local f = self.state.filter:lower()
            for _, l in ipairs(lines) do
                if l:lower():find(f, 1, true) then filtered[#filtered+1] = l end
            end
        end
        ui.write(panel.x, panel.y, "Filter: " .. (self.state.filter or "") .. "_", ui.DIM, ui.BG)
        ui.write(panel.x + panel.w - 8, panel.y, #filtered .. " lines", ui.DIM, ui.BG)
        local start = self.state.scroll + 1
        for i = start, math.min(#filtered, start + panel.h - 2) do
            local row = panel.y + 1 + (i - start)
            if row >= panel.y + panel.h then break end
            ui.write(panel.x, row, ui.truncate(filtered[i], panel.w), ui.DIM, ui.BG)
        end
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
            if ev[2] == keys.up then
                self.state.scroll = math.max(0, self.state.scroll - 1)
                self.dirty = true
            elseif ev[2] == keys.down then
                self.state.scroll = self.state.scroll + 1
                self.dirty = true
            elseif ev[2] == keys.backspace then
                if #(self.state.filter or "") > 0 then
                    self.state.filter = self.state.filter:sub(1, -2)
                    self.state.scroll = 0
                    self.dirty = true
                end
            end
        elseif ev[1] == "char" then
            self.state.filter = (self.state.filter or "") .. ev[2]
            self.state.scroll = 0
            self.dirty = true
        elseif ev[1] == "mouse_scroll" then
            self.state.scroll = math.max(0, self.state.scroll + ev[2])
            self.dirty = true
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "full_log_request_response" and msg.payload then
            self.state.logLines = msg.payload.log or {}
            self.dirty = true
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "full_log_request", { count = 200 }) end
    end,
})
