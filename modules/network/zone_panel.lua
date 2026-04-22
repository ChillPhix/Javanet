-- zone_panel.lua — Network Module
-- Shows zone list with occupancy and lockdown status.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("zone_panel", {
    name = "Zone Panel",
    domain = "network",
    min_size = { w = 18, h = 5 },
    pref_size = { w = 28, h = 10 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self) self.state.zones = {} end,

    render = function(self, panel)
        local zones = self.state.zones or {}
        if #zones == 0 then
            ui.write(panel.x, panel.y, "No zones", ui.DIM, ui.BG)
            return
        end
        for i, z in ipairs(zones) do
            local row = panel.y + i - 1
            if i > panel.h then break end
            local lockStr = z.locked and " [LOCKED]" or ""
            local lockCol = z.locked and ui.ERR or ui.OK
            local occ = z.occupants and #z.occupants or 0
            local occStr = occ > 0 and (" (" .. occ .. ")") or ""
            local text = ui.truncate(z.name .. lockStr .. occStr, panel.w)
            ui.write(panel.x, row, text, z.locked and ui.ERR or ui.FG, ui.BG)
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
