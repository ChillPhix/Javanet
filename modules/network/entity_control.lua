-- entity_control.lua — Network Module
-- Set entity status (contained/breached/testing/neutralized/etc.)

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

local STATUSES = {"contained", "breached", "testing", "transferred", "neutralized", "unknown"}

modules.register("entity_control", {
    name = "Entity Control",
    domain = "network",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 30, h = 10 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self) self.state.entities = {} self.state.selected = 1 end,

    render = function(self, panel)
        local items = {}
        for id, e in pairs(self.state.entities or {}) do items[#items+1] = { id = id, status = e.status or "?" } end
        table.sort(items, function(a, b) return a.id < b.id end)
        if #items == 0 then ui.write(panel.x, panel.y, "No entities", ui.DIM, ui.BG); return end
        for i, item in ipairs(items) do
            local row = panel.y + i - 1
            if i > panel.h - 1 then break end
            local prefix = (i == self.state.selected) and "> " or "  "
            local sCol = item.status == "contained" and ui.OK or (item.status == "breached" and ui.ERR or ui.WARN)
            ui.write(panel.x, row, prefix .. ui.truncate(item.id .. " [" .. item.status .. "]", panel.w), sCol, ui.BG)
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[ENTER] Cycle status", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" then
            if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
            elseif ev[2] == keys.enter then
                local items = {}
                for id, e in pairs(self.state.entities or {}) do items[#items+1] = { id = id, status = e.status } end
                table.sort(items, function(a, b) return a.id < b.id end)
                local item = items[self.state.selected]
                if item then
                    local curIdx = 1
                    for i, s in ipairs(STATUSES) do if s == item.status then curIdx = i; break end end
                    local newIdx = (curIdx % #STATUSES) + 1
                    local mfId = self.config.mainframeId
                    if mfId then proto.send(tonumber(mfId), "facility_command", { action = "set_entity_status", entityId = item.id, status = STATUSES[newIdx] }) end
                end
            end
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "status_request_response" and msg.payload then
            self.state.entities = msg.payload.entityList or {}
            self.dirty = true
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "status_request", {}) end
    end,
})
