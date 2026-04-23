-- remote_door.lua — Network Module
-- Open doors remotely by selecting from a list.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("remote_door", {
    name = "Remote Door",
    domain = "network",
    min_size = { w = 20, h = 5 },
    pref_size = { w = 28, h = 10 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self)
        self.state.scroll = 0 self.state.doors = {} self.state.selected = 1 end,

    render = function(self, panel)
        self._panel = panel
        ui.write(panel.x, panel.y, "REMOTE DOOR CONTROL", ui.ACCENT, ui.BG)
        local doors = self.state.doors or {}
        if #doors == 0 then ui.write(panel.x, panel.y + 1, "No doors registered", ui.DIM, ui.BG); return end
        for i, d in ipairs(doors) do
            local row = panel.y + i
            if row >= panel.y + panel.h then break end
            local prefix = (i == self.state.selected) and "> " or "  "
            ui.write(panel.x, row, prefix .. ui.truncate(d.label or ("#" .. d.id), panel.w), i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        ui.handlePanelScroll(self, ev)
        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local cy = ev[1] == "monitor_touch" and ev[4] or ev[4]
            if self._panel then
                local relY = cy - self._panel.y + 1
                local doors = self.state.doors or {}
                if relY >= 1 and relY <= #doors then
                    self.state.selected = relY
                    local d = doors[relY]
                    if d then
                        local mfId = self.config.mainframeId
                        if mfId then proto.send(tonumber(mfId), "door_command", { door = d.name, action = "open" }) end
                    end
                    self.dirty = true
                end
            end
        elseif ev[1] == "key" then
            local doors = self.state.doors or {}
            if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = math.min(#doors, self.state.selected + 1); self.dirty = true
            elseif ev[2] == keys.enter and doors[self.state.selected] then
                local d = doors[self.state.selected]
                proto.send(tonumber(d.id), "remote_open", {})
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
            local doors = {}
            -- Build door list from status
            self.dirty = true
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "status_request", {}) end
    end,
})
