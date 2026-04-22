-- personnel_lookup.lua — Network Module
-- Search and view personnel records.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("personnel_lookup", {
    name = "Personnel Lookup",
    domain = "network",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 35, h = 10 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self) self.state.searchBuffer = "" self.state.results = {} self.state.selected = 1 end,

    render = function(self, panel)
        ui.write(panel.x, panel.y, "Search: " .. self.state.searchBuffer .. "_", ui.ACCENT, ui.BG)
        local results = self.state.results or {}
        for i, r in ipairs(results) do
            local row = panel.y + i
            if row >= panel.y + panel.h then break end
            local prefix = (i == self.state.selected) and "> " or "  "
            local info = r.name .. " [CL:" .. (r.clearance or "?") .. "] " .. (r.department or "")
            ui.write(panel.x, row, prefix .. ui.truncate(info, panel.w), i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "char" then
            self.state.searchBuffer = self.state.searchBuffer .. ev[2]
            self.dirty = true
        elseif ev[1] == "key" then
            if ev[2] == keys.backspace then
                if #self.state.searchBuffer > 0 then self.state.searchBuffer = self.state.searchBuffer:sub(1, -2) end
                self.dirty = true
            elseif ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
            end
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "admin_command_response" and msg.payload then
            if msg.payload.personnel then
                local all = {}
                for name, p in pairs(msg.payload.personnel) do all[#all+1] = p end
                local q = self.state.searchBuffer:lower()
                if #q > 0 then
                    local filtered = {}
                    for _, p in ipairs(all) do
                        if (p.name or ""):lower():find(q, 1, true) then filtered[#filtered+1] = p end
                    end
                    self.state.results = filtered
                else
                    self.state.results = all
                end
                self.dirty = true
            end
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "admin_command", { command = "list_personnel", passcode = "" }) end
    end,
})
