-- entity_display.lua — Network Module
-- Shows entity info (class, status, threat, description).

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("entity_display", {
    name = "Entity Display",
    domain = "network",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 35, h = 12 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "entityId", type = "string", label = "Entity ID" },
    },

    init = function(self)
        self.state.scroll = 0 self.state.entity = nil self.state.breached = false end,

    render = function(self, panel)
        self._panel = panel
        local e = self.state.entity
        if not e then ui.write(panel.x, panel.y, "No data", ui.DIM, ui.BG); return end
        local y = panel.y
        if self.state.breached then
            ui.write(panel.x, y, "!! BREACH ACTIVE !!", ui.ERR, ui.BG)
            y = y + 1
        end
        ui.write(panel.x, y, e.id or "?", ui.ACCENT, ui.BG); y = y + 1
        ui.write(panel.x, y, "Name: " .. (e.name or "?"), ui.FG, ui.BG); y = y + 1
        ui.write(panel.x, y, "Class: " .. (e.class or "?"), ui.FG, ui.BG); y = y + 1
        local stCol = e.status == "contained" and ui.OK or ui.ERR
        ui.write(panel.x, y, "Status: " .. (e.status or "?"), stCol, ui.BG); y = y + 1
        ui.write(panel.x, y, "Threat: " .. string.rep("*", e.threat or 1), ui.WARN, ui.BG); y = y + 1
        if e.description and y < panel.y + panel.h then
            local desc = ui.truncate(e.description, panel.w)
            ui.write(panel.x, y, desc, ui.DIM, ui.BG)
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "chamber_info_response" and msg.payload then
            if msg.payload.found then
                self.state.entity = msg.payload.entity
                self.state.breached = msg.payload.breached
                self.dirty = true
            end
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        local eid = self.config.entityId
        if mfId and eid then proto.send(tonumber(mfId), "chamber_info", { entityId = eid }) end
    end,
})
