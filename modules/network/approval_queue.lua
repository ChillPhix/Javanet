-- approval_queue.lua — Network Module
-- Approve/reject pending terminal registrations.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("approval_queue", {
    name = "Approval Queue",
    domain = "network",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 35, h = 10 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "adminPasscode", type = "password", label = "Admin passcode" },
    },

    init = function(self)
        self.state.scroll = 0 self.state.pending = {} self.state.selected = 1 end,

    render = function(self, panel)
        self._panel = panel
        local pending = self.state.pending or {}
        local items = {}
        for id, info in pairs(pending) do items[#items+1] = { id = id, info = info } end
        if #items == 0 then ui.write(panel.x, panel.y, "No pending terminals", ui.OK, ui.BG); return end
        ui.write(panel.x, panel.y, #items .. " pending:", ui.WARN, ui.BG)
        for i, item in ipairs(items) do
            local row = panel.y + i
            if row >= panel.y + panel.h - 1 then break end
            local prefix = (i == self.state.selected) and "> " or "  "
            ui.write(panel.x, row, prefix .. "#" .. item.id .. " " .. (item.info.name or "?"), i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[A]pprove [R]eject", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        ui.handlePanelScroll(self, ev)
        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local cy = ev[1] == "monitor_touch" and ev[4] or ev[4]
            if self._panel then
                local relY = cy - self._panel.y + 1
                if relY >= 1 then
                    self.state.selected = relY
                    self.dirty = true
                end
            end
        elseif ev[1] == "key" then
            local items = {}
            for id, info in pairs(self.state.pending or {}) do items[#items+1] = { id = id, info = info } end
            if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = math.min(#items, self.state.selected + 1); self.dirty = true
            elseif ev[2] == keys.a and items[self.state.selected] then
                local mfId = self.config.mainframeId
                if mfId then proto.send(tonumber(mfId), "admin_command", { passcode = self.config.adminPasscode or "", command = "approve_pending", pendingId = items[self.state.selected].id }) end
            elseif ev[2] == keys.r and items[self.state.selected] then
                local mfId = self.config.mainframeId
                if mfId then proto.send(tonumber(mfId), "admin_command", { passcode = self.config.adminPasscode or "", command = "reject_pending", pendingId = items[self.state.selected].id }) end
            end
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "admin_command_response" and msg.payload then
            if msg.payload.pending then self.state.pending = msg.payload.pending; self.dirty = true end
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "admin_command", { passcode = self.config.adminPasscode or "", command = "list_pending" }) end
    end,
})
