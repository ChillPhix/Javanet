-- lockdown_control.lua — Network Module
-- Buttons to lock/unlock zones or full facility.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("lockdown_control", {
    name = "Lockdown Control",
    domain = "network",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 30, h = 10 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "minClearance", type = "number", label = "Min clearance", default = 1 },
    },

    init = function(self)
        self.state.zones = {}
        self.state.selected = 1
    end,

    render = function(self, panel)
        local zones = self.state.zones or {}
        if #zones == 0 then
            ui.write(panel.x, panel.y, "No zones loaded", ui.DIM, ui.BG)
            return
        end
        for i, z in ipairs(zones) do
            local row = panel.y + i - 1
            if i > panel.h - 1 then break end
            local lockStr = z.locked and "[LOCKED]" or "[ open ]"
            local lockCol = z.locked and ui.ERR or ui.OK
            local prefix = (i == self.state.selected) and "> " or "  "
            ui.write(panel.x, row, prefix .. ui.truncate(z.name, panel.w - 12) .. " " .. lockStr, i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[ENTER] Toggle  [A] All", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        local zones = self.state.zones or {}
        if ev[1] == "key" then
            if ev[2] == keys.up then
                self.state.selected = math.max(1, self.state.selected - 1)
                self.dirty = true
            elseif ev[2] == keys.down then
                self.state.selected = math.min(#zones, self.state.selected + 1)
                self.dirty = true
            elseif ev[2] == keys.enter and zones[self.state.selected] then
                local z = zones[self.state.selected]
                local action = z.locked and "unlock_zone" or "lockdown_zone"
                local mfId = self.config.mainframeId
                if mfId then
                    proto.send(tonumber(mfId), "facility_command", { action = action, zone = z.name })
                end
            elseif ev[2] == keys.a then
                local mfId = self.config.mainframeId
                if mfId then
                    for _, z in ipairs(zones) do
                        proto.send(tonumber(mfId), "facility_command", { action = "lockdown_zone", zone = z.name })
                    end
                end
            end
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "status_request_response" and msg.payload then
            self.state.zones = msg.payload.zones or {}
            self.dirty = true
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "status_request", {}) end
    end,
})
