-- facility_state.lua — Network Module
-- Change overall facility state (normal/alert/emergency/lockdown).

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

local STATES = {"normal", "alert", "emergency", "lockdown"}

modules.register("facility_state", {
    name = "Facility State",
    domain = "network",
    min_size = { w = 20, h = 5 },
    pref_size = { w = 28, h = 8 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self) self.state.currentState = "normal" self.state.selected = 1 end,

    render = function(self, panel)
        self._panel = panel
        local stateColors = { normal=ui.OK, alert=ui.WARN, emergency=ui.ERR, lockdown=ui.ERR }
        ui.write(panel.x, panel.y, "Current: " .. self.state.currentState:upper(), stateColors[self.state.currentState] or ui.FG, ui.BG)
        for i, s in ipairs(STATES) do
            local row = panel.y + i + 1
            if row >= panel.y + panel.h then break end
            local prefix = (i == self.state.selected) and "> " or "  "
            local col = (s == self.state.currentState) and ui.ACCENT or (stateColors[s] or ui.FG)
            ui.write(panel.x, row, prefix .. s:upper(), col, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local cy = ev[1] == "monitor_touch" and ev[4] or ev[4]
            if self._panel then
                local relY = cy - self._panel.y - 1
                if relY >= 1 and relY <= #STATES then
                    self.state.selected = relY
                    local mfId = self.config.mainframeId
                    if mfId then proto.send(tonumber(mfId), "facility_command", { action = "set_state", state = STATES[relY] }) end
                    self.dirty = true
                end
            end
        elseif ev[1] == "key" then
            if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = math.min(#STATES, self.state.selected + 1); self.dirty = true
            elseif ev[2] == keys.enter then
                local mfId = self.config.mainframeId
                if mfId then proto.send(tonumber(mfId), "facility_command", { action = "set_state", state = STATES[self.state.selected] }) end
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
            self.state.currentState = msg.payload.state or "normal"
            self.dirty = true
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "status_request", {}) end
    end,
})
