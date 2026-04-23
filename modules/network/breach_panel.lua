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

    init = function(self)
        self.state.scroll = 0 self.state.breaches = {} self.state.flash = false end,

    render = function(self, panel)
        self._panel = panel
        local lines = {}
        local breaches = self.state.breaches or {}
        if #breaches == 0 then
            lines[#lines+1] = {text = "NO ACTIVE BREACHES", color = ui.OK}
        else
            lines[#lines+1] = {text = "!! ACTIVE BREACHES: " .. #breaches .. " !!", color = ui.ERR}
            for _, b in ipairs(breaches) do
                lines[#lines+1] = {text = (b.entity or "?") .. " @ " .. (b.zone or "?"), color = ui.WARN}
                if b.severity then
                    lines[#lines+1] = {text = "  Severity: " .. b.severity, color = ui.DIM}
                end
            end
        end
        self.state.scroll = ui.renderPanelContent(panel, lines, self.state.scroll)
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
