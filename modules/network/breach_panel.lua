-- breach_panel.lua — Network Module
-- Shows active breaches with entity details and timestamps.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("breach_panel", {
    name = "Breach Panel",
    domain = "network",
    min_size = { w = 20, h = 5 },
    pref_size = { w = 30, h = 8 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self) self.state.breaches = {} self.state.flash = false end,

    render = function(self, panel)
        local breaches = self.state.breaches or {}
        local count = 0
        for _ in pairs(breaches) do count = count + 1 end
        if count == 0 then
            ui.write(panel.x, panel.y, "No active breaches", ui.OK, ui.BG)
            return
        end
        ui.write(panel.x, panel.y, "!! ACTIVE BREACHES: " .. count .. " !!", ui.ERR, ui.BG)
        local row = panel.y + 1
        for id, b in pairs(breaches) do
            if row >= panel.y + panel.h then break end
            ui.write(panel.x, row, ui.truncate("  " .. id, panel.w), ui.ERR, ui.BG)
            row = row + 1
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "status_request_response" and msg.payload then
            self.state.breaches = msg.payload.breachList or {}
            self.dirty = true
        elseif type(msg) == "table" and msg.type == "facility_update" then
            local p = msg.payload or {}
            if p.type == "breach" or p.type == "breach_end" then self.dirty = true end
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "status_request", {}) end
    end,
})
