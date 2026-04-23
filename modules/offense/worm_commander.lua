-- worm_commander.lua — Offense Module
-- Monitor deployed worms, authorize spread with mini-puzzles.
-- Listens on raw modem channels to communicate with worm payloads.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")
local puzzle = dofile("/jnet/lib/jnet_puzzle.lua")

local COMMANDER_CHANNEL = 7777
local WORM_CHANNEL = 7778

modules.register("worm_commander", {
    name = "Worm Commander",
    domain = "offense",
    min_size = { w = 25, h = 8 },
    pref_size = { w = 40, h = 14 },
    peripherals = {},
    config_fields = {},

    init = function(self)
        self.state.scroll = 0
        self.state.infections = {}
        self.state.pendingSpread = {}
        self.state.selected = 1
        self.state.log = {}
        -- Open raw modem channels for worm communication
        local modem = peripheral.find("modem")
        if modem then
            if not modem.isOpen(COMMANDER_CHANNEL) then modem.open(COMMANDER_CHANNEL) end
            if not modem.isOpen(WORM_CHANNEL) then modem.open(WORM_CHANNEL) end
        end
    end,

    render = function(self, panel)
        self._panel = panel
        ui.write(panel.x, panel.y, "WORM COMMANDER", ui.FG, ui.BG)
        ui.write(panel.x, panel.y + 1, "Infected: " .. #self.state.infections .. " | Pending: " .. #self.state.pendingSpread, ui.DIM, ui.BG)

        -- Show infections
        local row = panel.y + 2
        if #self.state.infections > 0 then
            for i, inf in ipairs(self.state.infections) do
                if row >= panel.y + panel.h - 2 then break end
                ui.write(panel.x + 1, row, "#" .. (inf.id or "?") .. " " .. (inf.label or "") .. " [WORM]", ui.OK, ui.BG)
                row = row + 1
            end
        end

        -- Show pending spread targets
        local pending = self.state.pendingSpread or {}
        if #pending > 0 then
            for i, t in ipairs(pending) do
                if row >= panel.y + panel.h - 1 then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                ui.write(panel.x, row, prefix .. "#" .. (t.id or "?") .. " " .. (t.label or "") .. " [SPREAD?]", i == self.state.selected and ui.WARN or ui.FG, ui.BG)
                row = row + 1
            end
        elseif #self.state.infections == 0 then
            ui.write(panel.x, row, "Deploy a worm first", ui.DIM, ui.BG)
        end

        -- Show recent log
        local logs = self.state.log or {}
        if #logs > 0 then
            local logRow = panel.y + panel.h - 2
            if logRow > row then
                local lastLog = logs[#logs]
                ui.write(panel.x, logRow, ui.truncate(lastLog, panel.w), ui.DIM, ui.BG)
            end
        end

        ui.write(panel.x, panel.y + panel.h - 1, "Tap to authorize spread", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        ui.handlePanelScroll(self, ev)
        -- Raw modem messages from worm payloads
        if ev[1] == "modem_message" then
            local ch = ev[3]
            local msg = ev[5]
            if (ch == COMMANDER_CHANNEL or ch == WORM_CHANNEL) and type(msg) == "table" then
                if msg.type == "worm_probe" then
                    -- Worm found a new target it could spread to
                    local targetId = msg.from
                    -- Check not already known
                    local known = false
                    for _, inf in ipairs(self.state.infections) do
                        if inf.id == targetId then known = true; break end
                    end
                    for _, p in ipairs(self.state.pendingSpread) do
                        if p.id == targetId then known = true; break end
                    end
                    if not known then
                        self.state.pendingSpread[#self.state.pendingSpread+1] = {
                            id = targetId, label = msg.label or "",
                        }
                        self.state.log[#self.state.log+1] = "New target: #" .. targetId
                    end
                    self.dirty = true
                elseif msg.type == "worm_data" then
                    -- Exfiltrated data received
                    self.state.log[#self.state.log+1] = "Data from #" .. (msg.from or "?")
                    self.dirty = true
                elseif msg.type == "worm_checkin" then
                    -- Worm checking in
                    local found = false
                    for _, inf in ipairs(self.state.infections) do
                        if inf.id == msg.from then found = true; break end
                    end
                    if not found then
                        self.state.infections[#self.state.infections+1] = {
                            id = msg.from, label = msg.label or "",
                        }
                        self.state.log[#self.state.log+1] = "Worm active on #" .. (msg.from or "?")
                    end
                    self.dirty = true
                end
            end
            return
        end

        -- Mouse/touch to select and authorize
        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local cy = ev[1] == "monitor_touch" and ev[4] or ev[4]
            if self._panel and #self.state.pendingSpread > 0 then
                local relY = cy - self._panel.y - 2 - #self.state.infections
                if relY >= 1 and relY <= #self.state.pendingSpread then
                    self.state.selected = relY
                    -- Auto-authorize on click (simplified — skip puzzle for now)
                    local target = self.state.pendingSpread[self.state.selected]
                    if target then
                        self.state.infections[#self.state.infections+1] = target
                        table.remove(self.state.pendingSpread, self.state.selected)
                        self.state.log[#self.state.log+1] = "Spread authorized: #" .. (target.id or "?")
                        -- Tell the worm to spread
                        local modem = peripheral.find("modem")
                        if modem then
                            modem.transmit(WORM_CHANNEL, WORM_CHANNEL, {
                                type = "worm_spread_authorized",
                                target = target.id,
                            })
                        end
                    end
                    self.dirty = true
                end
            end
        elseif ev[1] == "key" then
            if ev[2] == keys.up then
                self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then
                self.state.selected = self.state.selected + 1; self.dirty = true
            elseif ev[2] == keys.enter then
                local target = self.state.pendingSpread[self.state.selected]
                if target then
                    self.state.infections[#self.state.infections+1] = target
                    table.remove(self.state.pendingSpread, self.state.selected)
                    self.state.log[#self.state.log+1] = "Spread authorized: #" .. (target.id or "?")
                    local modem = peripheral.find("modem")
                    if modem then
                        modem.transmit(WORM_CHANNEL, WORM_CHANNEL, {
                            type = "worm_spread_authorized",
                            target = target.id,
                        })
                    end
                end
                self.dirty = true
            end
        end
    end,

    -- Also check via rednet in case something comes through there
    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "worm_status" and msg.payload then
            local found = false
            for _, inf in ipairs(self.state.infections) do
                if inf.id == senderId then found = true; break end
            end
            if not found then
                self.state.infections[#self.state.infections+1] = { id = senderId, label = msg.payload.label or "" }
            end
            self.dirty = true
        end
    end,

    tick = function(self)
        -- Periodically ping worms to get check-ins
        local modem = peripheral.find("modem")
        if modem then
            modem.transmit(WORM_CHANNEL, WORM_CHANNEL, {
                type = "worm_ping",
                from = os.getComputerID(),
            })
        end
    end,

    cleanup = function(self)
        local modem = peripheral.find("modem")
        if modem then
            if modem.isOpen(COMMANDER_CHANNEL) then modem.close(COMMANDER_CHANNEL) end
            if modem.isOpen(WORM_CHANNEL) then modem.close(WORM_CHANNEL) end
        end
    end,
})
