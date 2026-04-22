-- archive_browser.lua — Network Module
-- Server-wide document archive with folder browsing and clearance gating.

local modules = dofile("/jnet/lib/jnet_modules.lua")
local proto = dofile("/jnet/lib/jnet_proto.lua")
local ui = dofile("/jnet/lib/jnet_ui.lua")

modules.register("archive_browser", {
    name = "Archive Browser",
    domain = "network",
    min_size = { w = 25, h = 8 },
    pref_size = { w = 40, h = 14 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
    },

    init = function(self)
        self.state.view = "folders"
        self.state.folders = {}
        self.state.documents = {}
        self.state.currentFolder = nil
        self.state.currentDoc = nil
        self.state.selected = 1
        self.state.scroll = 0
    end,

    render = function(self, panel)
        self._panel = panel
        if self.state.view == "folders" then
            ui.write(panel.x, panel.y, "NETWORK ARCHIVE", ui.ACCENT, ui.BG)
            local folders = {}
            for name, f in pairs(self.state.folders or {}) do folders[#folders+1] = { name = name, cl = f.minClearance or 5 } end
            table.sort(folders, function(a, b) return a.name < b.name end)
            if #folders == 0 then ui.write(panel.x, panel.y + 1, "No folders", ui.DIM, ui.BG); return end
            for i, f in ipairs(folders) do
                local row = panel.y + i
                if row >= panel.y + panel.h then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                ui.write(panel.x, row, prefix .. f.name .. " [CL:" .. f.cl .. "]", i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
            end
        elseif self.state.view == "docs" then
            ui.write(panel.x, panel.y, "< " .. (self.state.currentFolder or "?"), ui.DIM, ui.BG)
            local docs = self.state.documents or {}
            if #docs == 0 then ui.write(panel.x, panel.y + 1, "Empty folder", ui.DIM, ui.BG); return end
            for i, d in ipairs(docs) do
                local row = panel.y + i
                if row >= panel.y + panel.h then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                ui.write(panel.x, row, prefix .. ui.truncate(d.title or "?", panel.w - 2), i == self.state.selected and ui.ACCENT or ui.FG, ui.BG)
            end
        elseif self.state.view == "read" then
            local doc = self.state.currentDoc
            if doc then
                ui.write(panel.x, panel.y, doc.title or "Document", ui.ACCENT, ui.BG)
                ui.write(panel.x, panel.y + 1, "By: " .. (doc.author or "?"), ui.DIM, ui.BG)
                local lines = {}
                for line in (doc.content or ""):gmatch("[^\n]+") do lines[#lines+1] = line end
                local start = self.state.scroll + 1
                for i = start, math.min(#lines, start + panel.h - 3) do
                    local row = panel.y + 2 + (i - start)
                    if row >= panel.y + panel.h then break end
                    ui.write(panel.x, row, ui.truncate(lines[i], panel.w), ui.FG, ui.BG)
                end
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
            if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
            elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
            elseif ev[2] == keys.enter then
                if self.state.view == "folders" then
                    local folders = {}
                    for name in pairs(self.state.folders or {}) do folders[#folders+1] = name end
                    table.sort(folders)
                    local sel = folders[self.state.selected]
                    if sel then
                        self.state.currentFolder = sel
                        self.state.view = "docs"
                        self.state.selected = 1
                        local mfId = self.config.mainframeId
                        if mfId then proto.send(tonumber(mfId), "archive_get_docs", { folder = sel }) end
                    end
                elseif self.state.view == "docs" then
                    local doc = (self.state.documents or {})[self.state.selected]
                    if doc then self.state.currentDoc = doc; self.state.view = "read"; self.state.scroll = 0 end
                end
                self.dirty = true
            elseif ev[2] == keys.backspace then
                if self.state.view == "read" then self.state.view = "docs"
                elseif self.state.view == "docs" then self.state.view = "folders" end
                self.state.selected = 1
                self.state.scroll = 0
                self.dirty = true
            end
        elseif ev[1] == "mouse_scroll" and self.state.view == "read" then
            self.state.scroll = math.max(0, self.state.scroll + ev[2])
            self.dirty = true
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "archive_list_response" and msg.payload then
            self.state.folders = (msg.payload.archive or {}).folders or {}
            self.dirty = true
        elseif type(msg) == "table" and msg.type == "archive_get_docs_response" and msg.payload then
            self.state.documents = msg.payload.documents or {}
            self.dirty = true
        end
    end,

    tick = function(self)
        if self.state.view == "folders" then
            local mfId = self.config.mainframeId
            if mfId then proto.send(tonumber(mfId), "archive_list", {}) end
        end
    end,
})
