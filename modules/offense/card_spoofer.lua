-- card_spoofer.lua — Offense Module
-- Clone, forge, or burn fake ID cards.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")
local puzzle = dofile("/jnet/lib/jnet_puzzle.lua")

modules.register("card_spoofer", {
    name = "Card Spoofer",
    domain = "offense",
    min_size = { w = 25, h = 8 },
    pref_size = { w = 35, h = 12 },
    peripherals = { "drive" },
    config_fields = {},

    init = function(self)
        self.state.scroll = 0
        self.state.mode = "menu"
        self.state.selected = 1
        self.state.options = {"Clone Card", "Forge Card (T3)", "Burn Card (T2)"}
    end,

    render = function(self, panel)
        self._panel = panel
        if self.state.mode == "menu" then
            ui.write(panel.x, panel.y, "CARD SPOOFER", ui.FG, ui.BG)
            for i, opt in ipairs(self.state.options) do
                local row = panel.y + i + 1
                if row >= panel.y + panel.h then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                ui.write(panel.x, row, prefix .. opt, i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
            end
        elseif self.state.mode == "result" then
            ui.write(panel.x, panel.y, self.state.message or "", self.state.success and ui.OK or ui.ERR, ui.BG)
            ui.write(panel.x, panel.y + 2, "[BKSP] Back", ui.DIM, ui.BG)
        end
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
            if self.state.mode == "menu" then
                if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
                elseif ev[2] == keys.down then self.state.selected = math.min(#self.state.options, self.state.selected + 1); self.dirty = true
                elseif ev[2] == keys.enter then
                    local drive = peripheral.find("drive")
                    if not drive or not drive.isDiskPresent() then
                        self.state.mode = "result"; self.state.message = "Insert disk first"; self.state.success = false
                    elseif self.state.selected == 1 then
                        self.state.mode = "result"; self.state.message = "Card cloned"; self.state.success = true
                    elseif self.state.selected == 2 then
                        local p = puzzle.generate(3, { target = "Card Forge" })
                        if p then
                            local r = puzzle.run(p)
                            self.state.mode = "result"
                            self.state.success = r.success
                            self.state.message = r.success and "Card forged (flaggable by IDS)" or "Forge failed"
                        end
                    elseif self.state.selected == 3 then
                        local p = puzzle.generate(2, { target = "Burn Card" })
                        if p then
                            local r = puzzle.run(p)
                            self.state.mode = "result"
                            self.state.success = r.success
                            self.state.message = r.success and "Burn card created (1 use, untraceable)" or "Burn failed"
                        end
                    end
                    self.dirty = true
                end
            elseif ev[2] == keys.backspace then
                self.state.mode = "menu"; self.dirty = true
            end

        elseif ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local cy = ev[1] == "monitor_touch" and ev[4] or ev[4]
            local cx = ev[1] == "monitor_touch" and ev[3] or ev[3]
            -- Click on list items to select and activate
            if self._panel then
                local relY = cy - self._panel.y
                if relY >= 1 and relY <= self._panel.h then
                    self.state.selected = relY
                    self.dirty = true
                end
            end
        end
    end,
})
