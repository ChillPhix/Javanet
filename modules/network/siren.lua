-- siren.lua — Network Module
-- Plays configurable alarm sounds via speaker peripheral.
-- Supports custom sound patterns, Minecraft sound events, and note sequences.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

-- Built-in alarm patterns
-- Each pattern is a list of {sound, volume, pitch} or {note, instrument, volume, pitch}
local ALARM_PATTERNS = {
    klaxon = {
        name = "Klaxon",
        type = "sound",
        sounds = {
            { "minecraft:block.note_block.bell", 3, 0.5 },
            { "minecraft:block.note_block.bell", 3, 0.7 },
            { "minecraft:block.note_block.bell", 3, 0.5 },
        },
        interval = 0.4,
    },
    wail = {
        name = "Wail Siren",
        type = "note",
        notes = {
            { "bell", 3, 6 },
            { "bell", 3, 8 },
            { "bell", 3, 10 },
            { "bell", 3, 12 },
            { "bell", 3, 14 },
            { "bell", 3, 16 },
            { "bell", 3, 18 },
            { "bell", 3, 16 },
            { "bell", 3, 14 },
            { "bell", 3, 12 },
            { "bell", 3, 10 },
            { "bell", 3, 8 },
        },
        interval = 0.15,
    },
    yelp = {
        name = "Yelp",
        type = "note",
        notes = {
            { "bell", 3, 18 },
            { "bell", 3, 6 },
        },
        interval = 0.2,
    },
    warble = {
        name = "Warble",
        type = "note",
        notes = {
            { "bit", 3, 12 },
            { "bit", 3, 18 },
            { "bit", 3, 12 },
            { "bit", 3, 6 },
        },
        interval = 0.12,
    },
    pulse = {
        name = "Pulse",
        type = "sound",
        sounds = {
            { "minecraft:block.note_block.pling", 3, 1.5 },
        },
        interval = 1.0,
    },
    raid = {
        name = "Raid Horn",
        type = "sound",
        sounds = {
            { "minecraft:event.raid.horn", 3, 1.0 },
        },
        interval = 3.0,
    },
    wither = {
        name = "Wither Warning",
        type = "sound",
        sounds = {
            { "minecraft:entity.wither.ambient", 2, 1.0 },
        },
        interval = 2.5,
    },
    guardian = {
        name = "Guardian Curse",
        type = "sound",
        sounds = {
            { "minecraft:entity.elder_guardian.curse", 3, 1.0 },
        },
        interval = 4.0,
    },
    custom = {
        name = "Custom",
        type = "sound",
        sounds = {},  -- filled from config
        interval = 1.0,
    },
}

local PATTERN_ORDER = {"klaxon", "wail", "yelp", "warble", "pulse", "raid", "wither", "guardian", "custom"}

modules.register("siren", {
    name = "Siren / Alarm",
    domain = "network",
    min_size = { w = 18, h = 5 },
    pref_size = { w = 28, h = 10 },
    peripherals = { "speaker" },
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "redstoneSide", type = "string", label = "Redstone out side", default = "" },
        { key = "pattern", type = "string", label = "Alarm pattern", default = "klaxon" },
        { key = "customSound", type = "string", label = "Custom sound ID", default = "" },
        { key = "customPitch", type = "number", label = "Custom pitch (0.5-2.0)", default = 1.0 },
        { key = "customInterval", type = "number", label = "Custom interval (sec)", default = 1.0 },
        { key = "autoActivate", type = "bool", label = "Auto on emergency", default = true },
    },

    init = function(self)
        self.state.scroll = 0
        self.state.active = false
        self.state.selectedPattern = 1
        self.state.noteIndex = 1
        self.state.lastPlay = 0

        -- Setup custom sound from config
        if self.config.customSound and #self.config.customSound > 0 then
            ALARM_PATTERNS.custom.sounds = {
                { self.config.customSound, 3, self.config.customPitch or 1.0 },
            }
            ALARM_PATTERNS.custom.interval = self.config.customInterval or 1.0
        end

        -- Find selected pattern index
        local patName = self.config.pattern or "klaxon"
        for i, p in ipairs(PATTERN_ORDER) do
            if p == patName then self.state.selectedPattern = i; break end
        end
    end,

    render = function(self, panel)
        self._panel = panel
        local lines = {}

        if self.state.active then
            lines[#lines+1] = {text = "!! SIREN ACTIVE !!", color = ui.ERR}
        else
            lines[#lines+1] = {text = "SIREN: STANDBY", color = ui.DIM}
        end

        lines[#lines+1] = ""

        -- Show pattern selector
        local currentKey = PATTERN_ORDER[self.state.selectedPattern] or "klaxon"
        local currentPat = ALARM_PATTERNS[currentKey]
        lines[#lines+1] = {text = "Pattern: " .. (currentPat and currentPat.name or currentKey), color = ui.ACCENT}

        lines[#lines+1] = ""

        -- Buttons
        if self.state.active then
            lines[#lines+1] = {text = "[ TAP TO SILENCE ]", color = ui.OK}
        else
            lines[#lines+1] = {text = "[ TAP TO ACTIVATE ]", color = ui.WARN}
        end

        lines[#lines+1] = {text = "< > Change pattern", color = ui.DIM}

        self.state.scroll = ui.renderPanelContent(panel, lines, self.state.scroll)
    end,

    handleEvent = function(self, ev)
        ui.handlePanelScroll(self, ev)

        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            -- Tap to toggle
            self.state.active = not self.state.active
            local side = self.config.redstoneSide
            if side and #side > 0 then
                redstone.setOutput(side, self.state.active)
            end
            self.dirty = true

        elseif ev[1] == "key" then
            if ev[2] == keys.enter or ev[2] == keys.space then
                self.state.active = not self.state.active
                local side = self.config.redstoneSide
                if side and #side > 0 then
                    redstone.setOutput(side, self.state.active)
                end
                self.dirty = true
            elseif ev[2] == keys.left then
                self.state.selectedPattern = self.state.selectedPattern - 1
                if self.state.selectedPattern < 1 then self.state.selectedPattern = #PATTERN_ORDER end
                self.state.noteIndex = 1
                self.dirty = true
            elseif ev[2] == keys.right then
                self.state.selectedPattern = self.state.selectedPattern + 1
                if self.state.selectedPattern > #PATTERN_ORDER then self.state.selectedPattern = 1 end
                self.state.noteIndex = 1
                self.dirty = true
            end
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "facility_update" then
            local p = msg.payload or {}
            if p.type == "state" and self.config.autoActivate then
                local wasActive = self.state.active
                self.state.active = (p.state == "emergency" or p.state == "lockdown")
                if self.state.active ~= wasActive then
                    local side = self.config.redstoneSide
                    if side and #side > 0 then
                        redstone.setOutput(side, self.state.active)
                    end
                    self.dirty = true
                end
            end
        end
    end,

    tick = function(self)
        if not self.state.active then return end

        local speaker = peripheral.find("speaker")
        if not speaker then return end

        local now = os.epoch("utc") / 1000
        local patKey = PATTERN_ORDER[self.state.selectedPattern] or "klaxon"
        local pat = ALARM_PATTERNS[patKey]
        if not pat then return end

        local interval = pat.interval or 0.5
        if now - self.state.lastPlay < interval then return end
        self.state.lastPlay = now

        if pat.type == "sound" and pat.sounds and #pat.sounds > 0 then
            local idx = self.state.noteIndex
            if idx > #pat.sounds then idx = 1 end
            local s = pat.sounds[idx]
            pcall(function() speaker.playSound(s[1], s[2] or 3, s[3] or 1.0) end)
            self.state.noteIndex = idx + 1
            if self.state.noteIndex > #pat.sounds then self.state.noteIndex = 1 end

        elseif pat.type == "note" and pat.notes and #pat.notes > 0 then
            local idx = self.state.noteIndex
            if idx > #pat.notes then idx = 1 end
            local n = pat.notes[idx]
            pcall(function() speaker.playNote(n[1], n[2] or 3, n[3] or 12) end)
            self.state.noteIndex = idx + 1
            if self.state.noteIndex > #pat.notes then self.state.noteIndex = 1 end
        end
    end,

    cleanup = function(self)
        local side = self.config.redstoneSide
        if side and #side > 0 then redstone.setOutput(side, false) end
    end,
})
