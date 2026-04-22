-- status_panel.lua — Network Module
-- Shows facility state, zone status, breach list, entity counts.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("status_panel", {
    name = "Status Panel",
    domain = "network",
    min_size = { w = 20, h = 6 },
    pref_size = { w = 30, h = 10 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self)
        self.state.status = nil
        self.state.pollTimer = nil
    end,

    render = function(self, panel)
        local s = self.state.status
        if not s then
            ui.write(panel.x, panel.y + 1, "Connecting...", ui.DIM, ui.BG)
            return
        end
        local y = panel.y
        local stateColors = { normal=ui.OK, alert=ui.WARN, emergency=ui.ERR, lockdown=ui.ERR }
        ui.write(panel.x, y, "State: ", ui.DIM, ui.BG)
        ui.write(panel.x + 7, y, (s.state or "?"):upper(), stateColors[s.state] or ui.FG, ui.BG)
        y = y + 1
        ui.write(panel.x, y, "Personnel: " .. (s.personnel or 0), ui.FG, ui.BG)
        y = y + 1
        ui.write(panel.x, y, "Terminals: " .. (s.terminals or 0), ui.FG, ui.BG)
        y = y + 1
        ui.write(panel.x, y, "Entities:  " .. (s.entities or 0), ui.FG, ui.BG)
        y = y + 1
        local bCol = (s.breaches or 0) > 0 and ui.ERR or ui.OK
        ui.write(panel.x, y, "Breaches:  " .. (s.breaches or 0), bCol, ui.BG)
        y = y + 1
        if (s.infections or 0) > 0 then
            ui.write(panel.x, y, "Infections: " .. s.infections, ui.ERR, ui.BG)
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "status_request_response" then
            self.state.status = msg.payload
            self.dirty = true
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then
            proto.send(tonumber(mfId), "status_request", {})
        end
    end,
})
