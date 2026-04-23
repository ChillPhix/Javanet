-- door_lock.lua — Network Module
-- Controls redstone output to open/close doors.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("door_lock", {
    name = "Door Lock",
    domain = "network",
    min_size = { w = 15, h = 3 },
    pref_size = { w = 20, h = 5 },
    peripherals = {},
    config_fields = {
        { key = "side", type = "string", label = "Redstone side", default = "back" },
        { key = "openDuration", type = "number", label = "Open time (sec)", default = 3 },
        { key = "inverted", type = "bool", label = "Invert signal" },
    },

    init = function(self)
        self.state.scroll = 0
        self.state.isOpen = false
        self.state.closeTimer = nil
        local side = self.config.side or "back"
        if self.config.inverted then
            redstone.setOutput(side, true)
        else
            redstone.setOutput(side, false)
        end
    end,

    render = function(self, panel)
        self._panel = panel
        local cy = panel.y + math.floor(panel.h / 2)
        if self.state.isOpen then
            ui.write(panel.x, cy, ui.pad("DOOR OPEN", panel.w, " ", "center"), ui.OK, ui.BG)
        else
            ui.write(panel.x, cy, ui.pad("DOOR LOCKED", panel.w, " ", "center"), ui.ERR, ui.BG)
        end
    end,

    handleEvent = function(self, ev)
        ui.handlePanelScroll(self, ev)
        -- Listen for card_reader doorOpen state changes
        -- In practice, the runtime links card_reader state to door_lock
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "remote_open" then
            self:openDoor()
        elseif type(msg) == "table" and msg.type == "facility_update" then
            local p = msg.payload or {}
            if p.type == "lockdown" and p.zone == self.config.zone then
                self:closeDoor()
            end
        end
    end,

    tick = function(self)
        -- Check if any sibling card_reader has doorOpen
        -- This is handled by the runtime's module linking
    end,

    cleanup = function(self)
        local side = self.config.side or "back"
        redstone.setOutput(side, false)
    end,
})

-- Helper methods attached to instances
local def = modules.getDef("door_lock")
function def.openDoor(self)
    local side = self.config.side or "back"
    local signal = not self.config.inverted
    redstone.setOutput(side, signal)
    self.state.isOpen = true
    self.dirty = true
    local duration = self.config.openDuration or 3
    if self.state.closeTimer then os.cancelTimer(self.state.closeTimer) end
    self.state.closeTimer = os.startTimer(duration)
end

function def.closeDoor(self)
    local side = self.config.side or "back"
    local signal = self.config.inverted and true or false
    redstone.setOutput(side, signal)
    self.state.isOpen = false
    self.dirty = true
end
