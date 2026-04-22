-- mail_client.lua — Network Module
-- Compose, read, reply, delete internal messages.

local modules = require("lib.jnet_modules")
local proto = require("lib.jnet_proto")
local ui = require("lib.jnet_ui")

modules.register("mail_client", {
    name = "Mail",
    domain = "network",
    min_size = { w = 25, h = 8 },
    pref_size = { w = 40, h = 14 },
    peripherals = {},
    config_fields = {
        { key = "mainframeId", type = "number", label = "Mainframe ID" },
        { key = "userName", type = "string", label = "Your name" },
    },

    init = function(self)
        self.state.view = "inbox"
        self.state.inbox = {}
        self.state.selected = 1
        self.state.currentMail = nil
        self.state.unread = 0
    end,

    render = function(self, panel)
        if self.state.view == "inbox" then
            local badge = self.state.unread > 0 and (" (" .. self.state.unread .. " new)") or ""
            ui.write(panel.x, panel.y, "INBOX" .. badge, ui.ACCENT, ui.BG)
            ui.write(panel.x + panel.w - 6, panel.y, "[C]ompose", ui.DIM, ui.BG)
            local inbox = self.state.inbox or {}
            if #inbox == 0 then ui.write(panel.x, panel.y + 1, "No messages", ui.DIM, ui.BG); return end
            for i, m in ipairs(inbox) do
                local row = panel.y + i
                if row >= panel.y + panel.h then break end
                local prefix = (i == self.state.selected) and "> " or "  "
                local readMark = m.read and " " or "*"
                local text = readMark .. ui.truncate((m.from or "?") .. ": " .. (m.subject or ""), panel.w - 4)
                ui.write(panel.x, row, prefix .. text, m.read and ui.DIM or ui.FG, ui.BG)
            end
        elseif self.state.view == "read" then
            local m = self.state.currentMail
            if m then
                ui.write(panel.x, panel.y, "From: " .. (m.from or "?"), ui.ACCENT, ui.BG)
                ui.write(panel.x, panel.y + 1, "Subj: " .. (m.subject or ""), ui.FG, ui.BG)
                local lines = {}
                for line in (m.body or ""):gmatch("[^\n]+") do lines[#lines+1] = line end
                for i, line in ipairs(lines) do
                    local row = panel.y + 2 + i
                    if row >= panel.y + panel.h - 1 then break end
                    ui.write(panel.x, row, ui.truncate(line, panel.w), ui.FG, ui.BG)
                end
                ui.write(panel.x, panel.y + panel.h - 1, "[R]eply [D]elete [BKSP]Back", ui.DIM, ui.BG)
            end
        end
    end,

    handleEvent = function(self, ev)
        if ev[1] == "key" then
            if self.state.view == "inbox" then
                if ev[2] == keys.up then self.state.selected = math.max(1, self.state.selected - 1); self.dirty = true
                elseif ev[2] == keys.down then self.state.selected = self.state.selected + 1; self.dirty = true
                elseif ev[2] == keys.enter then
                    local m = (self.state.inbox or {})[self.state.selected]
                    if m then
                        self.state.currentMail = m
                        self.state.view = "read"
                        local mfId = self.config.mainframeId
                        if mfId then proto.send(tonumber(mfId), "mail_read", { mailId = m.id }) end
                    end
                    self.dirty = true
                end
            elseif self.state.view == "read" then
                if ev[2] == keys.backspace then
                    self.state.view = "inbox"; self.dirty = true
                elseif ev[2] == keys.d then
                    local m = self.state.currentMail
                    if m then
                        local mfId = self.config.mainframeId
                        if mfId then proto.send(tonumber(mfId), "mail_delete", { mailId = m.id }) end
                    end
                    self.state.view = "inbox"; self.dirty = true
                end
            end
            if ev[2] == keys.c then
                -- Compose
                ui.clear()
                ui.header(ui.facilityName, "COMPOSE")
                local to = ui.prompt(4, "To: ")
                local subject = ui.prompt(6, "Subject: ")
                local body = ui.prompt(8, "Message: ")
                if to and #to > 0 then
                    local mfId = self.config.mainframeId
                    if mfId then
                        proto.send(tonumber(mfId), "mail_send", {
                            from = self.config.userName or "Unknown",
                            to = to, subject = subject or "", body = body or "",
                        })
                    end
                end
                self.dirty = true
            end
        end
    end,

    handleNetwork = function(self, senderId, msg)
        if type(msg) == "table" and msg.type == "mail_inbox_response" and msg.payload then
            self.state.inbox = msg.payload.inbox or {}
            self.state.unread = 0
            for _, m in ipairs(self.state.inbox) do if not m.read then self.state.unread = self.state.unread + 1 end end
            self.dirty = true
        end
    end,

    tick = function(self)
        local mfId = self.config.mainframeId
        if mfId then proto.send(tonumber(mfId), "mail_inbox", { name = self.config.userName or "" }) end
    end,
})
