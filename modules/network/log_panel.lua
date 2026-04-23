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

    init = function(self)
        self.state.scroll = 0 self.state.logLines = {} end,

    render = function(self, panel)
        self._panel = panel
        local lines = {}
        lines[#lines+1] = {text = "RECENT LOG", color = ui.FG}
        local logs = self.state.logs or {}
        if #logs == 0 then
            lines[#lines+1] = {text = "No log entries", color = ui.DIM}
        else
            for i = #logs, math.max(1, #logs - 100), -1 do
                if logs[i] then lines[#lines+1] = logs[i] end
            end
        end
        self.state.scroll = ui.renderPanelContent(panel, lines, self.state.scroll)
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
