-- agent_control.lua — Offense Module
-- Monitor, ping, and control deployed stealth agents.
-- Listens on raw modem channel 5555 for agent reports.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

local AGENT_CHANNEL = 5555

modules.register("agent_control", {
    name = "Agent Control",
    domain = "offense",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 35, h = 12 },
    peripherals = {},
    config_fields = {},

    init = function(self)
        self.state.agents = {}
        self.state.reports = {}
        self.state.selected = 1
        -- Open raw modem channel for agent communication
        local modem = peripheral.find("modem")
        if modem then
            if not modem.isOpen(AGENT_CHANNEL) then modem.open(AGENT_CHANNEL) end
        end
    end,

    render = function(self, panel)
        self._panel = panel
        ui.write(panel.x, panel.y, "AGENT CONTROL", ui.FG, ui.BG)

        local agents = self.state.agents or {}
        if #agents == 0 then
            ui.write(panel.x, panel.y + 1, "No agents deployed", ui.DIM, ui.BG)
            ui.write(panel.x, panel.y + 2, "Deploy via payload_deployer", ui.DIM, ui.BG)
        else
            for i, a in ipairs(agents) do
                local row = panel.y + i
                if row >= panel.y + panel.h - 3 then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                local status = a.alive and "[ALIVE]" or "[???]"
                local col = a.alive and ui.OK or ui.DIM
                ui.write(panel.x, row, prefix .. "#" .. (a.id or "?") .. " " .. status, col, ui.BG)
            end
        end

        -- Show recent reports
        local reports = self.state.reports or {}
        local reportStart = panel.y + panel.h - 3
        if #reports > 0 then
            ui.write(panel.x, reportStart, "RECENT:", ui.DIM, ui.BG)
            for i = math.max(1, #reports - 1), #reports do
                local row = reportStart + (i - math.max(1, #reports - 1)) + 1
                if row < panel.y + panel.h - 1 then
                    local r = reports[i]
                    ui.write(panel.x + 1, row, ui.truncate(r, panel.w - 2), ui.WARN, ui.BG)
                end
            end
        end

        ui.write(panel.x, panel.y + panel.h - 1, "[Tap]Select [P]ing [Enter]Toggle", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
        -- Raw modem messages from agents
        if ev[1] == "modem_message" then
            local ch = ev[3]
            local msg = ev[5]
            if ch == AGENT_CHANNEL and type(msg) == "table" then
                if msg.type == "agent_report" then
                    -- Card swipe report
                    local report = "#" .. (msg.from or "?") .. " SWIPE disk:" .. tostring(msg.diskId)
                    self.state.reports[#self.state.reports+1] = report
                    if #self.state.reports > 50 then table.remove(self.state.reports, 1) end

                    -- Track agent
                    local found = false
                    for _, a in ipairs(self.state.agents) do
                        if a.id == msg.from then found = true; a.alive = true; break end
                    end
                    if not found then
                        self.state.agents[#self.state.agents+1] = { id = msg.from, alive = true }
                    end
                    self.dirty = true

                elseif msg.type == "agent_checkin" then
                    -- Ping response
                    local found = false
                    for _, a in ipairs(self.state.agents) do
                        if a.id == msg.from then found = true; a.alive = true; break end
                    end
                    if not found then
                        self.state.agents[#self.state.agents+1] = { id = msg.from, alive = true }
                    end
                    self.dirty = true
                end
            end
            return
        end

        -- Mouse/touch
        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local cy = ev[1] == "monitor_touch" and ev[4] or ev[4]
            if self._panel then
                local relY = cy - self._panel.y
                if relY >= 1 and relY <= #self.state.agents then
                    self.state.selected = relY
                    self.dirty = true
                end
            end
        elseif ev[1] == "key" then
            if ev[2] == keys.up then
                self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then
                self.state.selected = self.state.selected + 1; self.dirty = true
            elseif ev[2] == keys.enter then
                -- Toggle agent
                local a = self.state.agents[self.state.selected]
                if a then a.alive = not a.alive; self.dirty = true end
            elseif ev[2] == keys.p then
                -- Ping selected agent
                local a = self.state.agents[self.state.selected]
                if a then
                    local modem = peripheral.find("modem")
                    if modem then
                        modem.transmit(AGENT_CHANNEL, AGENT_CHANNEL, {
                            type = "agent_ping",
                            from = os.getComputerID(),
                        })
                    end
                    self.dirty = true
                end
            end
        end
    end,

    -- Also handle rednet messages
    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "agent_checkin" then
            local found = false
            for _, a in ipairs(self.state.agents) do
                if a.id == senderId then found = true; a.alive = true; break end
            end
            if not found then
                self.state.agents[#self.state.agents+1] = { id = senderId, alive = true }
            end
            self.dirty = true
        end
    end,

    tick = function(self)
        -- Mark agents as unknown after no check-in
        -- (they'll come back alive on next report/ping response)
    end,

    cleanup = function(self)
        local modem = peripheral.find("modem")
        if modem then
            if modem.isOpen(AGENT_CHANNEL) then modem.close(AGENT_CHANNEL) end
        end
    end,
})
