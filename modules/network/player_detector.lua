-- player_detector.lua — Network Module
-- Reports nearby players to mainframe for zone tracking.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("player_detector", {
    name = "Player Detector",
    domain = "network",
    min_size = { w = 18, h = 4 },
    pref_size = { w = 25, h = 8 },
    peripherals = { "playerDetector" },
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "zone", type = "string", label = "Zone name" },
        { key = "range", type = "number", label = "Detection range", default = 10 },
    },

    init = function(self)
        self.state.scroll = 0 self.state.players = {} end,

    render = function(self, panel)
        self._panel = panel
        local players = self.state.players or {}
        ui.write(panel.x, panel.y, "Zone: " .. (self.config.zone or "?"), ui.DIM, ui.BG)
        ui.write(panel.x, panel.y + 1, "Detected: " .. #players, ui.FG, ui.BG)
        for i, p in ipairs(players) do
            local row = panel.y + 2 + i - 1
            if row >= panel.y + panel.h then break end
            ui.write(panel.x + 1, row, p, ui.ACCENT, ui.BG)
        end
    end,

    tick = function(self)
        local detector = peripheral.find("playerDetector")
        if detector then
            local ok, players = pcall(function() return detector.getPlayersInRange(self.config.range or 10) end)
            if ok and players then
                local names = {}
                for _, p in ipairs(players) do names[#names+1] = type(p) == "table" and p.name or tostring(p) end
                self.state.players = names
                local mfId = self.config.mainframeId
                if mfId then
                    proto.send(tonumber(mfId), "detector_report", { zone = self.config.zone, players = names })
                end
                self.dirty = true
            end
        end
    end,
})
