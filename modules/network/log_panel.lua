-- log_panel.lua — Network Module
-- Shows recent security log entries, auto-scrolling.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("log_panel", {
    name = "Log Panel",
    domain = "network",
    min_size = { w = 25, h = 5 },
    pref_size = { w = 40, h = 10 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "logCount", type = "number", label = "Lines to show", default = 10 },
    },

    init = function(self) self.state.logLines = {} end,

    render = function(self, panel)
        self._panel = panel
        local lines = self.state.logLines or {}
        if #lines == 0 then
            ui.write(panel.x, panel.y, "No log entries", ui.DIM, ui.BG)
            return
        end
        local start = math.max(1, #lines - panel.h + 1)
        for i = start, #lines do
            local row = panel.y + (i - start)
            if row >= panel.y + panel.h then break end
            ui.write(panel.x, row, ui.truncate(lines[i], panel.w), ui.DIM, ui.BG)
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "full_log_request_response" and msg.payload then
            self.state.logLines = msg.payload.log or {}
            self.dirty = true
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then
            proto.send(tonumber(mfId), "full_log_request", { count = self.config.logCount or 10 })
        end
    end,
})
