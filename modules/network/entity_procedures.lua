-- entity_procedures.lua — Network Module
-- Card-gated classified procedure viewing.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("entity_procedures", {
    name = "Procedures",
    domain = "network",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 35, h = 12 },
    peripherals = { "drive" },
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "entityId", type = "string", label = "Entity ID" },
        { key = "minClearance", type = "number", label = "Min clearance", default = 2 },
    },

    init = function(self) self.state.unlocked = false self.state.procedures = "" end,

    render = function(self, panel)
        self._panel = panel
        if not self.state.unlocked then
            ui.write(panel.x, panel.y + math.floor(panel.h/2), "CLASSIFIED", ui.ERR, ui.BG)
            ui.write(panel.x, panel.y + math.floor(panel.h/2) + 1, "Insert ID card", ui.DIM, ui.BG)
        else
            local lines = {}
            for line in self.state.procedures:gmatch("[^\n]+") do lines[#lines+1] = line end
            for i, line in ipairs(lines) do
                local row = panel.y + i - 1
                if row >= panel.y + panel.h then break end
                ui.write(panel.x, row, ui.truncate(line, panel.w), ui.FG, ui.BG)
            end
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "disk" then
            local drive = peripheral.find("drive")
            if drive and drive.isDiskPresent() then
                local diskId = drive.getDiskID()
                local mfId = self.config.mainframeId
                if mfId and diskId then
                    local resp = proto.request(tonumber(mfId), "auth_request", { diskId = diskId }, 5)
                    if resp and resp.payload and resp.payload.granted then
                        if resp.payload.clearance <= (self.config.minClearance or 2) then
                            self.state.unlocked = true
                            -- Fetch procedures
                            local eid = self.config.entityId
                            if eid then
                                local info = proto.request(tonumber(mfId), "chamber_info", { entityId = eid }, 5)
                                if info and info.payload and info.payload.entity then
                                    self.state.procedures = info.payload.entity.procedures or "No procedures on file."
                                end
                            end
                        end
                    end
                end
                self.dirty = true
            end
        elseif ev[1] == "disk_eject" then
            self.state.unlocked = false
            self.dirty = true
        end
    end,
})
