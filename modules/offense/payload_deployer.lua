-- payload_deployer.lua — Offense Module
-- Push lockout/worm/backdoor/agent to compromised targets.
-- Sends payload SOURCE CODE over rednet to a deploy handler on the target.
-- Requires a valid crack session on the target.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

-- Read a payload file and return its source code
local function readPayload(name)
    local path = "/jnet/payloads/" .. name .. ".lua"
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    local code = f.readAll()
    f.close()
    return code
end

modules.register("payload_deployer", {
    name = "Payload Deployer",
    domain = "offense",
    min_size = { w = 25, h = 8 },
    pref_size = { w = 35, h = 12 },
    peripherals = {},
    config_fields = {},

    init = function(self)
        self.state.payloads = {"lockout", "worm", "backdoor", "agent"}
        self.state.selected = 1
        self.state.targetBuffer = ""
        self.state.phase = "target"  -- target, select, deploying, deployed, error
        self.state.statusMsg = ""
        self.state.scroll = 0
    end,

    render = function(self, panel)
        self._panel = panel
        local lines = {}

        if self.state.phase == "target" then
            lines[#lines+1] = {text = "PAYLOAD DEPLOYER", color = ui.FG}
            lines[#lines+1] = ""
            lines[#lines+1] = "Enter target computer ID:"
            lines[#lines+1] = {text = "> " .. self.state.targetBuffer .. "_", color = ui.ACCENT}
            lines[#lines+1] = ""
            lines[#lines+1] = {text = "Type ID then press ENTER", color = ui.DIM}

        elseif self.state.phase == "select" then
            lines[#lines+1] = {text = "TARGET: #" .. self.state.targetBuffer, color = ui.FG}
            lines[#lines+1] = {text = "Select payload:", color = ui.DIM}
            lines[#lines+1] = ""
            for i, p in ipairs(self.state.payloads) do
                local prefix = (i == self.state.selected) and "> " or "  "
                local desc = ""
                if p == "lockout" then desc = " (screen takeover)"
                elseif p == "worm" then desc = " (spread+persist)"
                elseif p == "backdoor" then desc = " (remote access)"
                elseif p == "agent" then desc = " (stealth keylog)"
                end
                lines[#lines+1] = {
                    text = prefix .. p:upper() .. desc,
                    color = i == self.state.selected and ui.ACCENT or ui.FG,
                }
            end
            lines[#lines+1] = ""
            lines[#lines+1] = {text = "Tap or ENTER to deploy", color = ui.DIM}
            lines[#lines+1] = {text = "BACKSPACE to go back", color = ui.DIM}

        elseif self.state.phase == "deploying" then
            lines[#lines+1] = {text = "DEPLOYING...", color = ui.WARN}
            lines[#lines+1] = self.state.statusMsg

        elseif self.state.phase == "deployed" then
            lines[#lines+1] = {text = "PAYLOAD DEPLOYED!", color = ui.OK}
            lines[#lines+1] = self.state.statusMsg
            lines[#lines+1] = ""
            lines[#lines+1] = {text = "Tap or BACKSPACE to continue", color = ui.DIM}

        elseif self.state.phase == "error" then
            lines[#lines+1] = {text = "DEPLOY FAILED", color = ui.ERR}
            lines[#lines+1] = self.state.statusMsg
            lines[#lines+1] = ""
            lines[#lines+1] = {text = "Tap or BACKSPACE to retry", color = ui.DIM}
        end

        self.state.scroll = ui.renderPanelContent(panel, lines, self.state.scroll)
    end,

    handleEvent = function(self, ev)
        ui.handlePanelScroll(self, ev)

        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            if self.state.phase == "select" then
                local cy = ev[1] == "monitor_touch" and ev[4] or ev[4]
                if self._panel then
                    local relY = cy - self._panel.y - 2  -- account for header lines
                    if relY >= 1 and relY <= #self.state.payloads then
                        self.state.selected = relY
                        -- Deploy on click
                        self:_deploy()
                    end
                end
            elseif self.state.phase == "deployed" or self.state.phase == "error" then
                self.state.phase = "target"
                self.state.targetBuffer = ""
                self.dirty = true
            end

        elseif ev[1] == "key" then
            if self.state.phase == "target" then
                if ev[2] == keys.enter and #self.state.targetBuffer > 0 then
                    self.state.phase = "select"
                    self.dirty = true
                elseif ev[2] == keys.backspace then
                    if #self.state.targetBuffer > 0 then
                        self.state.targetBuffer = self.state.targetBuffer:sub(1, -2)
                        self.dirty = true
                    end
                end
            elseif self.state.phase == "select" then
                if ev[2] == keys.up then
                    self.state.selected = math.max(1, self.state.selected - 1)
                    self.dirty = true
                elseif ev[2] == keys.down then
                    self.state.selected = math.min(#self.state.payloads, self.state.selected + 1)
                    self.dirty = true
                elseif ev[2] == keys.enter then
                    self:_deploy()
                elseif ev[2] == keys.backspace then
                    self.state.phase = "target"
                    self.dirty = true
                end
            elseif self.state.phase == "deployed" or self.state.phase == "error" then
                if ev[2] == keys.backspace or ev[2] == keys.enter then
                    self.state.phase = "target"
                    self.state.targetBuffer = ""
                    self.dirty = true
                end
            end

        elseif ev[1] == "char" and self.state.phase == "target" then
            if ev[2]:match("[0-9]") then
                self.state.targetBuffer = self.state.targetBuffer .. ev[2]
                self.dirty = true
            end
        end
    end,
})

-- Deploy method
local def = modules.getDef("payload_deployer")
function def._deploy(self)
    local tid = tonumber(self.state.targetBuffer)
    local payloadName = self.state.payloads[self.state.selected]
    if not tid then
        self.state.phase = "error"
        self.state.statusMsg = "Invalid target ID"
        self.dirty = true
        return
    end

    self.state.phase = "deploying"
    self.state.statusMsg = payloadName:upper() .. " -> #" .. tid
    self.dirty = true

    -- Read the payload source code
    local code = readPayload(payloadName)
    if not code then
        self.state.phase = "error"
        self.state.statusMsg = "Payload file not found!"
        self.dirty = true
        return
    end

    -- Send payload code directly to the target via ATK protocol
    -- The target needs a deploy listener (installed by a previous crack)
    proto.sendAtk(tid, "deploy_payload", {
        payloadType = payloadName,
        code = code,
        attacker = os.getComputerID(),
    })

    -- Also notify the mainframe (for logging)
    proto.sendAtk(tid, "deploy", {
        deployType = payloadName,
        targetComp = tid,
    })

    self.state.phase = "deployed"
    self.state.statusMsg = payloadName:upper() .. " sent to #" .. tid
    self.dirty = true
end
