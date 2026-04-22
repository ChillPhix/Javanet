-- jnet_ui.lua
-- Themed UI library for Javanet terminals.
-- Supports full faction theming, role-based border styles,
-- adaptive layouts, and monitor-aware rendering.
-- Place at /lib/jnet_ui.lua on every Javanet computer.

local M = {}

-- ============================================================
-- Color System
-- ============================================================

M.COLOR_NAMES = {
    "white","orange","magenta","lightBlue","yellow","lime",
    "pink","gray","lightGray","cyan","purple","blue",
    "brown","green","red","black",
}

M.COLOR_MAP = {
    white=colors.white, orange=colors.orange, magenta=colors.magenta,
    lightBlue=colors.lightBlue, yellow=colors.yellow, lime=colors.lime,
    pink=colors.pink, gray=colors.gray, lightGray=colors.lightGray,
    cyan=colors.cyan, purple=colors.purple, blue=colors.blue,
    brown=colors.brown, green=colors.green, red=colors.red, black=colors.black,
}

local function colorByName(name)
    return M.COLOR_MAP[name] or colors.yellow
end

-- ============================================================
-- Theme State
-- ============================================================

M.BG      = colors.black
M.FG      = colors.yellow
M.DIM     = colors.gray
M.BORDER  = colors.yellow
M.OK      = colors.lime
M.WARN    = colors.orange
M.ERR     = colors.red
M.ACCENT  = colors.white
M.HIGHLIGHT = colors.lightBlue

-- Faction identity
M.facilityName     = "JAVANET"
M.facilitySubtitle = "SYSTEM"
M.facilityMotto    = ""
M.fgColorName      = "yellow"
M.bgColorName      = "black"
M.logoLines        = nil

-- ============================================================
-- Color Scheme Application
-- ============================================================

function M.applyColors(fgName, bgName)
    fgName = fgName or "yellow"
    bgName = bgName or "black"
    M.fgColorName = fgName
    M.bgColorName = bgName
    M.FG     = colorByName(fgName)
    M.BG     = colorByName(bgName)
    M.BORDER = M.FG
    if bgName == "black" or bgName == "gray" or bgName == "brown" then
        M.DIM = colors.gray
    else
        M.DIM = colors.lightGray
    end
    if bgName == "white" or bgName == "lightGray" then
        M.ACCENT = colors.black
        M.HIGHLIGHT = colors.blue
    else
        M.ACCENT = colors.white
        M.HIGHLIGHT = colors.lightBlue
    end
end

function M.applyIdentity(identity)
    if not identity then return end
    M.facilityName     = identity.name or M.facilityName
    M.facilitySubtitle = identity.subtitle or M.facilitySubtitle
    M.facilityMotto    = identity.motto or M.facilityMotto or ""
    M.applyColors(identity.fgColor or "yellow", identity.bgColor or "black")
end

-- ============================================================
-- Identity Caching
-- ============================================================

local IDENTITY_PATH = "/.jnet_identity"

function M.cacheIdentity()
    local f = fs.open(IDENTITY_PATH, "w")
    f.write(textutils.serialize({
        name = M.facilityName,
        subtitle = M.facilitySubtitle,
        motto = M.facilityMotto,
        fgColor = M.fgColorName,
        bgColor = M.bgColorName,
    }))
    f.close()
end

function M.loadCachedIdentity()
    if not fs.exists(IDENTITY_PATH) then return false end
    local f = fs.open(IDENTITY_PATH, "r")
    local s = f.readAll(); f.close()
    local ok, t = pcall(textutils.unserialize, s)
    if ok and type(t) == "table" then
        M.applyIdentity(t)
        return true
    end
    return false
end

-- ============================================================
-- Logo Loading
-- ============================================================

function M.loadLogo(path)
    path = path or "/.jnet_logo.txt"
    if not fs.exists(path) then M.logoLines = nil; return false end
    local f = fs.open(path, "r")
    local text = f.readAll(); f.close()
    M.logoLines = {}
    for line in text:gmatch("[^\n]+") do
        M.logoLines[#M.logoLines+1] = line
    end
    return true
end

-- ============================================================
-- Basic Drawing Primitives
-- ============================================================

local function getTarget()
    return term.current()
end

function M.getSize()
    return term.getSize()
end

function M.clear()
    term.setBackgroundColor(M.BG)
    term.setTextColor(M.FG)
    term.clear()
    term.setCursorPos(1, 1)
end

function M.write(x, y, text, fg, bg)
    local W, H = M.getSize()
    if y < 1 or y > H or x > W then return end
    term.setCursorPos(x, y)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    local maxLen = W - x + 1
    if #text > maxLen then text = text:sub(1, maxLen) end
    term.write(text)
end

function M.centerWrite(y, text, fg, bg)
    local W = M.getSize()
    if #text > W then text = text:sub(1, W) end
    local x = math.floor((W - #text) / 2) + 1
    M.write(x, y, text, fg, bg)
end

function M.fillLine(y, ch, fg, bg)
    local W, H = M.getSize()
    if y < 1 or y > H then return end
    ch = ch or " "
    term.setCursorPos(1, y)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    term.write(string.rep(ch, W))
end

function M.fillRect(x, y, w, h, ch, fg, bg)
    ch = ch or " "
    for row = y, y + h - 1 do
        M.write(x, row, string.rep(ch, w), fg, bg)
    end
end

function M.hline(x, y, len, ch, fg)
    ch = ch or string.char(196) -- ─
    M.write(x, y, string.rep(ch, len), fg or M.BORDER)
end

function M.vline(x, y, len, ch, fg)
    ch = ch or string.char(179) -- │
    for i = 0, len - 1 do
        M.write(x, y + i, ch, fg or M.BORDER)
    end
end

-- ============================================================
-- Border Styles (varies by domain)
-- ============================================================

M.BORDER_STYLES = {
    network = {
        tl = "+", tr = "+", bl = "+", br = "+",
        h = "-", v = "|", title_l = "[ ", title_r = " ]",
    },
    offense = {
        tl = "#", tr = "#", bl = "#", br = "#",
        h = "=", v = "!", title_l = "< ", title_r = " >",
    },
    defense = {
        tl = "[", tr = "]", bl = "[", br = "]",
        h = "=", v = "#", title_l = "{ ", title_r = " }",
    },
    default = {
        tl = "+", tr = "+", bl = "+", br = "+",
        h = "-", v = "|", title_l = "[ ", title_r = " ]",
    },
}

function M.getBorderStyle(domain)
    return M.BORDER_STYLES[domain] or M.BORDER_STYLES.default
end

-- ============================================================
-- Box / Panel Drawing
-- ============================================================

function M.box(x, y, w, h, title, domain, fg, bg)
    local s = M.getBorderStyle(domain or "default")
    local borderFg = fg or M.BORDER
    local bgCol = bg or M.BG

    -- Top border
    local topLine = s.tl .. string.rep(s.h, w - 2) .. s.tr
    if title and #title > 0 then
        local tl = s.title_l .. title .. s.title_r
        local pos = 2
        if #tl <= w - 4 then
            topLine = s.tl .. s.h .. tl .. string.rep(s.h, w - 3 - #tl) .. s.tr
        end
    end
    M.write(x, y, topLine, borderFg, bgCol)

    -- Sides
    for row = y + 1, y + h - 2 do
        M.write(x, row, s.v, borderFg, bgCol)
        M.write(x + 1, row, string.rep(" ", w - 2), nil, bgCol)
        M.write(x + w - 1, row, s.v, borderFg, bgCol)
    end

    -- Bottom border
    M.write(x, y + h - 1, s.bl .. string.rep(s.h, w - 2) .. s.br, borderFg, bgCol)
end

function M.panel(x, y, w, h, title, domain)
    M.box(x, y, w, h, title, domain, M.FG, M.BG)
end

-- ============================================================
-- Header / Footer
-- ============================================================

function M.header(title, subtitle)
    local W = M.getSize()
    M.fillLine(1, " ", M.BG, M.FG)
    title = title or M.facilityName
    subtitle = subtitle or M.facilitySubtitle
    local full = title
    if subtitle and #subtitle > 0 then full = full .. " - " .. subtitle end
    if #full > W then full = full:sub(1, W) end
    local x = math.floor((W - #full) / 2) + 1
    M.write(x, 1, full, M.BG, M.FG)
end

function M.footer(text)
    local W, H = M.getSize()
    M.fillLine(H, " ", M.BG, M.FG)
    if text then
        if #text > W then text = text:sub(1, W) end
        local x = math.floor((W - #text) / 2) + 1
        M.write(x, H, text, M.BG, M.FG)
    end
end

-- ============================================================
-- Status Displays
-- ============================================================

function M.bigStatus(y, text, color)
    local W, H = M.getSize()
    color = color or M.FG
    M.fillLine(y, " ", nil, M.BG)
    M.centerWrite(y, text, color, M.BG)
end

function M.statusBar(y, fields)
    local W = M.getSize()
    M.fillLine(y, " ", M.DIM, M.BG)
    local x = 2
    for _, field in ipairs(fields) do
        local label = field[1] .. ": "
        local value = tostring(field[2])
        local col = field[3] or M.FG
        M.write(x, y, label, M.DIM, M.BG)
        x = x + #label
        M.write(x, y, value, col, M.BG)
        x = x + #value + 2
        if x >= W - 2 then break end
    end
end

-- ============================================================
-- Progress Bars
-- ============================================================

function M.progressBar(x, y, w, pct, fg, bg, style)
    pct = math.max(0, math.min(1, pct))
    style = style or "solid"
    local filled = math.floor(w * pct)
    local fgCol = fg or M.OK
    local bgCol = bg or M.DIM
    if style == "solid" then
        M.write(x, y, string.rep(string.char(127), filled), fgCol, M.BG)
        M.write(x + filled, y, string.rep(string.char(176), w - filled), bgCol, M.BG)
    elseif style == "segmented" then
        for i = 0, w - 1 do
            local ch = i < filled and "#" or "-"
            local col = i < filled and fgCol or bgCol
            M.write(x + i, y, ch, col, M.BG)
        end
    elseif style == "bracket" then
        M.write(x, y, "[", M.BORDER, M.BG)
        local inner = w - 2
        local innerFilled = math.floor(inner * pct)
        M.write(x+1, y, string.rep("=", innerFilled), fgCol, M.BG)
        M.write(x+1+innerFilled, y, string.rep(" ", inner - innerFilled), bgCol, M.BG)
        M.write(x+w-1, y, "]", M.BORDER, M.BG)
    end
end

-- ============================================================
-- Interactive Elements
-- ============================================================

function M.prompt(y, label, maxLen)
    local W, H = M.getSize()
    maxLen = maxLen or (W - #label - 4)
    M.write(2, y, label, M.FG, M.BG)
    term.setCursorPos(2 + #label, y)
    term.setTextColor(M.ACCENT)
    term.setBackgroundColor(M.BG)
    term.setCursorBlink(true)
    local input = read(nil, nil, nil, nil)
    term.setCursorBlink(false)
    return input
end

function M.passwordPrompt(y, label)
    local W, H = M.getSize()
    M.write(2, y, label, M.FG, M.BG)
    term.setCursorPos(2 + #label, y)
    term.setTextColor(M.ACCENT)
    term.setBackgroundColor(M.BG)
    term.setCursorBlink(true)
    local input = read("*")
    term.setCursorBlink(false)
    return input
end

function M.confirm(y, text)
    M.write(2, y, text .. " (y/n) ", M.FG, M.BG)
    while true do
        local _, key = os.pullEvent("char")
        if key == "y" or key == "Y" then return true end
        if key == "n" or key == "N" then return false end
    end
end

-- ============================================================
-- Scrollable Lists
-- ============================================================

function M.scrollList(x, y, w, h, items, selected, scroll, highlight)
    selected = selected or 1
    scroll = scroll or 0
    highlight = highlight or M.HIGHLIGHT
    for i = 1, h do
        local idx = scroll + i
        local row = y + i - 1
        if idx <= #items then
            local text = tostring(items[idx])
            if #text > w - 2 then text = text:sub(1, w - 3) .. "." end
            text = " " .. text .. string.rep(" ", w - 2 - #text)
            if idx == selected then
                M.write(x, row, text, M.BG, highlight)
            else
                M.write(x, row, text, M.FG, M.BG)
            end
        else
            M.write(x, row, string.rep(" ", w), M.FG, M.BG)
        end
    end
    return scroll
end

-- Returns: selected index, action ("select", "back", "scroll")
function M.runScrollList(x, y, w, h, items, selected, scroll)
    selected = selected or 1
    scroll = scroll or 0
    while true do
        M.scrollList(x, y, w, h, items, selected, scroll)
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "key" then
            if p1 == keys.up then
                selected = selected - 1
                if selected < 1 then selected = #items end
                if selected <= scroll then scroll = selected - 1 end
                if selected > scroll + h then scroll = selected - h end
            elseif p1 == keys.down then
                selected = selected + 1
                if selected > #items then selected = 1 end
                if selected > scroll + h then scroll = selected - h end
                if selected <= scroll then scroll = 0 end
            elseif p1 == keys.enter then
                return selected, "select"
            elseif p1 == keys.backspace or p1 == keys.q then
                return selected, "back"
            end
        elseif ev == "mouse_click" or ev == "monitor_touch" then
            local clickY = p3
            if clickY >= y and clickY < y + h then
                local idx = scroll + (clickY - y + 1)
                if idx <= #items then
                    selected = idx
                    return selected, "select"
                end
            end
        elseif ev == "mouse_scroll" then
            scroll = scroll + p1
            scroll = math.max(0, math.min(#items - h, scroll))
        end
    end
end

-- ============================================================
-- Menu System
-- ============================================================

function M.menu(title, options, domain)
    M.clear()
    M.header(M.facilityName, title)
    local W, H = M.getSize()
    local listH = H - 4
    local selected, action = M.runScrollList(2, 3, W - 2, listH, options, 1, 0)
    if action == "select" then return selected end
    return nil
end

-- ============================================================
-- Modal Dialogs
-- ============================================================

function M.alert(title, message, domain)
    local W, H = M.getSize()
    local bw = math.min(W - 4, math.max(#message + 4, #title + 8, 30))
    local bh = 7
    local bx = math.floor((W - bw) / 2) + 1
    local by = math.floor((H - bh) / 2) + 1
    M.box(bx, by, bw, bh, title, domain)
    M.centerWrite(by + 2, message, M.FG, M.BG)
    M.centerWrite(by + 4, "[ OK ]", M.ACCENT, M.BG)
    while true do
        local ev, p1 = os.pullEvent()
        if ev == "key" and (p1 == keys.enter or p1 == keys.space) then return end
        if ev == "mouse_click" or ev == "monitor_touch" then return end
    end
end

function M.confirmDialog(title, message, domain)
    local W, H = M.getSize()
    local bw = math.min(W - 4, math.max(#message + 4, #title + 8, 30))
    local bh = 7
    local bx = math.floor((W - bw) / 2) + 1
    local by = math.floor((H - bh) / 2) + 1
    M.box(bx, by, bw, bh, title, domain)
    M.centerWrite(by + 2, message, M.FG, M.BG)
    local yesX = bx + math.floor(bw / 4) - 2
    local noX = bx + math.floor(3 * bw / 4) - 2
    M.write(yesX, by + 4, "[ YES ]", M.OK, M.BG)
    M.write(noX, by + 4, "[ NO ]", M.ERR, M.BG)
    while true do
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "key" then
            if p1 == keys.y then return true end
            if p1 == keys.n or p1 == keys.backspace then return false end
        elseif ev == "char" then
            if p1 == "y" or p1 == "Y" then return true end
            if p1 == "n" or p1 == "N" then return false end
        end
    end
end

function M.inputDialog(title, label, domain, isPassword)
    local W, H = M.getSize()
    local bw = math.min(W - 4, 40)
    local bh = 7
    local bx = math.floor((W - bw) / 2) + 1
    local by = math.floor((H - bh) / 2) + 1
    M.box(bx, by, bw, bh, title, domain)
    M.write(bx + 2, by + 2, label, M.FG, M.BG)
    term.setCursorPos(bx + 2, by + 3)
    term.setTextColor(M.ACCENT)
    term.setBackgroundColor(M.BG)
    term.setCursorBlink(true)
    local input
    if isPassword then
        input = read("*")
    else
        input = read()
    end
    term.setCursorBlink(false)
    return input
end

function M.pickDialog(title, options, domain)
    local W, H = M.getSize()
    local bw = math.min(W - 4, 40)
    local maxItems = math.min(#options, H - 8)
    local bh = maxItems + 4
    local bx = math.floor((W - bw) / 2) + 1
    local by = math.floor((H - bh) / 2) + 1
    M.box(bx, by, bw, bh, title, domain)
    local sel, action = M.runScrollList(bx + 1, by + 1, bw - 2, maxItems, options, 1, 0)
    if action == "select" then return sel, options[sel] end
    return nil
end

-- ============================================================
-- Color Picker
-- ============================================================

function M.colorPicker(y, label, current)
    local W = M.getSize()
    M.write(2, y, label, M.FG, M.BG)
    local x = #label + 3
    local sel = 1
    for i, name in ipairs(M.COLOR_NAMES) do
        if name == current then sel = i; break end
    end
    while true do
        -- Draw swatches
        local cx = x
        for i, name in ipairs(M.COLOR_NAMES) do
            local c = M.COLOR_MAP[name]
            local ch = i == sel and "##" or "  "
            M.write(cx, y, ch, colors.white, c)
            cx = cx + 2
            if cx > W - 2 then break end
        end
        M.write(cx + 1, y, M.COLOR_NAMES[sel] .. "   ", M.DIM, M.BG)
        local ev, p1 = os.pullEvent()
        if ev == "key" then
            if p1 == keys.left then
                sel = sel - 1; if sel < 1 then sel = #M.COLOR_NAMES end
            elseif p1 == keys.right then
                sel = sel + 1; if sel > #M.COLOR_NAMES then sel = 1 end
            elseif p1 == keys.enter then
                return M.COLOR_NAMES[sel]
            elseif p1 == keys.backspace then
                return current
            end
        end
    end
end

-- ============================================================
-- Notification Badges
-- ============================================================

function M.badge(x, y, text, fg, bg)
    bg = bg or M.ERR
    fg = fg or M.ACCENT
    M.write(x, y, " " .. text .. " ", fg, bg)
end

function M.flashBadge(x, y, text, cycles)
    cycles = cycles or 3
    for i = 1, cycles do
        M.badge(x, y, text, M.ACCENT, M.ERR)
        sleep(0.3)
        M.badge(x, y, text, M.ERR, M.BG)
        sleep(0.2)
    end
    M.badge(x, y, text, M.ACCENT, M.ERR)
end

-- ============================================================
-- Utility
-- ============================================================

function M.truncate(text, maxLen)
    if #text <= maxLen then return text end
    return text:sub(1, maxLen - 2) .. ".."
end

function M.pad(text, len, ch, align)
    ch = ch or " "
    align = align or "left"
    if #text >= len then return text:sub(1, len) end
    local pad = string.rep(ch, len - #text)
    if align == "right" then return pad .. text end
    if align == "center" then
        local half = math.floor(#pad / 2)
        return pad:sub(1, half) .. text .. pad:sub(half + 1)
    end
    return text .. pad
end

function M.timestamp()
    return os.date("%H:%M:%S")
end

function M.formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

return M
