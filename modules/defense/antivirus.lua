-- antivirus.lua — Defense Module
-- Scan local + network for agents, worms, backdoors. Quarantine/purge.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("antivirus", {
    name = "Antivirus",
    domain = "defense",
    min_size = { w = 22, h = 6 },
    pref_size = { w = 35, h = 10 },
    peripherals = {},
    config_fields = {},

    init = function(self) self.state.threats = {} self.state.lastScan = nil end,

    render = function(self, panel)
        self._panel = panel
        ui.write(panel.x, panel.y, "ANTIVIRUS", ui.FG, ui.BG)
        ui.write(panel.x, panel.y + 1, "Last scan: " .. (self.state.lastScan or "never"), ui.DIM, ui.BG)
        local threats = self.state.threats or {}
        if #threats == 0 then
            ui.write(panel.x, panel.y + 2, "System clean", ui.OK, ui.BG)
        else
            for i, t in ipairs(threats) do
                local row = panel.y + 2 + i
                if row >= panel.y + panel.h - 1 then break end
                ui.write(panel.x, row, "! " .. t, ui.ERR, ui.BG)
            end
        end
        ui.write(panel.x, panel.y + panel.h - 1, "[S]can [P]urge all", ui.DIM, ui.BG)
    end,

    handleEvent = function(self, ev)
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
            if ev[2] == keys.s then
                -- Scan for known infection signatures
                self.state.threats = {}
                if fs.exists("/.sys_jnet.lua") then self.state.threats[#self.state.threats+1] = "WORM: /.sys_jnet.lua" end
                if fs.exists("/.sys.lua") then self.state.threats[#self.state.threats+1] = "AGENT: /.sys.lua" end
                if fs.exists("/.jnet_backdoor") then self.state.threats[#self.state.threats+1] = "BACKDOOR: /.jnet_backdoor" end
                -- Check startup for hooks
                if fs.exists("/startup.lua") then
                    local f = fs.open("/startup.lua", "r")
                    local content = f.readAll(); f.close()
                    if content:find("sys_jnet") or content:find("%.sys%.lua") then
                        self.state.threats[#self.state.threats+1] = "HOOK in startup.lua"
                    end
                end
                self.state.lastScan = os.date("%H:%M:%S")
                self.dirty = true
            elseif ev[2] == keys.p then
                -- Purge all known threats
                pcall(fs.delete, "/.sys_jnet.lua")
                pcall(fs.delete, "/.sys.lua")
                pcall(fs.delete, "/.jnet_backdoor")
                self.state.threats = {}
                self.state.lastScan = "PURGED " .. os.date("%H:%M:%S")
                self.dirty = true
            end
        end
    end,
})
