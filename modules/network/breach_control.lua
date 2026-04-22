-- breach_control.lua — Network Module
-- Declare/end entity breaches.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("breach_control", {
    name = "Breach Control",
    domain = "network",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 30, h = 10 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self)
        self.state.entities = {}
        self.state.breaches = {}
        self.state.selected = 1
    end,

    render = function(self, panel)
        self._panel = panel
        local entities = self.state.entities or {}
        local breaches = self.state.breaches or {}
        local items = {}
        for id, e in pairs(entities) do items[#items+1] = { id = id, name = e.name or id, breached = breaches[id] ~= nil } end
        table.sort(items, function(a, b) return a.id < b.id end)
        if #items == 0 then
            ui.write(panel.x, panel.y, "No entities", ui.DIM, ui.BG)
            return
        end
        for i, item in ipairs(items) do
            local row = panel.y + i - 1
            if i > panel.h - 1 then break end
            local status = item.breached and "[BREACH]" or "[CONT.]"
            local col = item.breached and ui.ERR or ui.OK
            local prefix = (i == self.state.selected) and "> " or "  "
            ui.write(panel.x, row, prefix .. ui.truncate(item.id .. " " .. status, panel.w), i == self.state.selected and ui.ACCENT or col, ui.BG)
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[Tap/Enter] Toggle breach", ui.DIM, ui.BG)
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
            if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
            elseif ev[2] == keys.enter then
                local entities = {}
                for id, e in pairs(self.state.entities or {}) do entities[#entities+1] = { id = id } end
                table.sort(entities, function(a, b) return a.id < b.id end)
                local item = entities[self.state.selected]
                if item then
                    local mfId = self.config.mainframeId
                    local breached = (self.state.breaches or {})[item.id]
                    local action = breached and "end_breach" or "declare_breach"
                    if mfId then proto.send(tonumber(mfId), "facility_command", { action = action, entityId = item.id }) end
                end
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

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "status_request_response" and msg.payload then
            self.state.entities = msg.payload.entityList or {}
            self.state.breaches = msg.payload.breachList or {}
            self.dirty = true
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "status_request", {}) end
    end,
})
