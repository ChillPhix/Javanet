-- integrity_check.lua — Defense Module
-- Monitor startup.lua and system files for unauthorized changes.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("integrity_check", {
    name = "File Integrity",
    domain = "defense",
    min_size = { w = 22, h = 5 },
    pref_size = { w = 30, h = 8 },
    peripherals = {},
    config_fields = {},

    init = function(self)
        self.state.hashes = {}
        self.state.alerts = {}
        self.state.status = "OK"
        -- Snapshot current files
        local files = {"/startup.lua", "/.jnet_config", "/.jnet_secret"}
        for _, f in ipairs(files) do
            if fs.exists(f) then
                local fh = fs.open(f, "r")
                local content = fh.readAll(); fh.close()
                self.state.hashes[f] = #content .. ":" .. content:sub(1, 20)
            end
        end
    end,

    render = function(self, panel)
        local col = self.state.status == "OK" and ui.OK or ui.ERR
        ui.write(panel.x, panel.y, "INTEGRITY: " .. self.state.status, col, ui.BG)
        for i, a in ipairs(self.state.alerts or {}) do
            local row = panel.y + i
            if row >= panel.y + panel.h then break end
            ui.write(panel.x, row, "! " .. a, ui.ERR, ui.BG)
        end
    end,

    tick = function(self)
        self.state.alerts = {}
        local files = {"/startup.lua", "/.jnet_config", "/.jnet_secret"}
        for _, f in ipairs(files) do
            if fs.exists(f) then
                local fh = fs.open(f, "r")
                local content = fh.readAll(); fh.close()
                local hash = #content .. ":" .. content:sub(1, 20)
                if self.state.hashes[f] and self.state.hashes[f] ~= hash then
                    self.state.alerts[#self.state.alerts+1] = "MODIFIED: " .. f
                end
            elseif self.state.hashes[f] then
                self.state.alerts[#self.state.alerts+1] = "DELETED: " .. f
            end
        end
        -- Check for new suspicious files
        if fs.exists("/.sys_jnet.lua") then self.state.alerts[#self.state.alerts+1] = "SUSPICIOUS: /.sys_jnet.lua" end
        if fs.exists("/.sys.lua") then self.state.alerts[#self.state.alerts+1] = "SUSPICIOUS: /.sys.lua" end
        self.state.status = #self.state.alerts > 0 and "COMPROMISED" or "OK"
        if #self.state.alerts > 0 then self.dirty = true end
    end,
})
