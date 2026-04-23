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

    init = function(self)
        self.state.scroll = 0 self.state.zones = {} end,

    render = function(self, panel)
        self._panel = panel
        local lines = {}
        lines[#lines+1] = {text = "ZONES", color = ui.FG}
        local zones = self.state.zones or {}
        if #zones == 0 then
            lines[#lines+1] = {text = "No zones loaded", color = ui.DIM}
        else
            for _, z in ipairs(zones) do
                local status = z.locked and "[LOCKED]" or "[open]"
                local col = z.locked and ui.ERR or ui.OK
                local occ = z.occupants and (" (" .. #z.occupants .. ")") or ""
                lines[#lines+1] = {text = ui.fit((z.name or "?") .. occ .. " " .. status, panel.w), color = col}
            end
        end
        self.state.scroll = ui.renderPanelContent(panel, lines, self.state.scroll)
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
