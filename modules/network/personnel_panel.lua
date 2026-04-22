-- personnel_panel.lua — Network Module
-- Shows personnel count, online users, clearance breakdown.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("personnel_panel", {
    name = "Personnel Panel",
    domain = "network",
    min_size = { w = 18, h = 5 },
    pref_size = { w = 28, h = 8 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self) self.state.count = 0 end,

    render = function(self, panel)
        ui.write(panel.x, panel.y, "Personnel: " .. self.state.count, ui.FG, ui.BG)
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "status_request_response" and msg.payload then
            self.state.count = msg.payload.personnel or 0
            self.dirty = true
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "status_request", {}) end
    end,
})
