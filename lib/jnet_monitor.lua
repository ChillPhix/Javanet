-- jnet_monitor.lua
-- Multi-monitor manager for Javanet terminals.
-- Handles detection, adaptive layouts, mirroring, and touch routing.
-- Place at /lib/jnet_monitor.lua on every Javanet computer.

local M = {}

M.monitors = {}
M.primaryMonitor = nil
M.mirrorMode = false

-- ============================================================
-- Monitor Detection
-- ============================================================

function M.detectMonitors()
    M.monitors = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "monitor" then
            local mon = peripheral.wrap(name)
            local w, h = mon.getSize()
            M.monitors[#M.monitors+1] = {
                name = name,
                wrap = mon,
                width = w,
                height = h,
                side = name,
            }
        end
    end
    -- Pick largest as primary
    if #M.monitors > 0 then
        table.sort(M.monitors, function(a, b)
            return (a.width * a.height) > (b.width * b.height)
        end)
        M.primaryMonitor = M.monitors[1]
    else
        M.primaryMonitor = nil
    end
    return #M.monitors
end

function M.hasPrimary()
    return M.primaryMonitor ~= nil
end

function M.getPrimarySize()
    if not M.primaryMonitor then return term.getSize() end
    return M.primaryMonitor.wrap.getSize()
end

-- ============================================================
-- Monitor Output Helpers
-- ============================================================

function M.setPrimary()
    if M.primaryMonitor then
        term.redirect(M.primaryMonitor.wrap)
        return true
    end
    return false
end

function M.restoreTerminal()
    term.redirect(term.native())
end

function M.clearPrimary(bg)
    if not M.primaryMonitor then return end
    local mon = M.primaryMonitor.wrap
    mon.setBackgroundColor(bg or colors.black)
    mon.clear()
    mon.setCursorPos(1, 1)
end

function M.writePrimary(x, y, text, fg, bg)
    if not M.primaryMonitor then return end
    local mon = M.primaryMonitor.wrap
    mon.setCursorPos(x, y)
    if fg then mon.setTextColor(fg) end
    if bg then mon.setBackgroundColor(bg) end
    mon.write(text)
end

-- ============================================================
-- Multi-Term Wrapper (for mirroring)
-- ============================================================

function M.createMultiTerm(targets)
    local multi = {}
    local w, h = targets[1].getSize()

    local function callAll(method, ...)
        local result
        for _, t in ipairs(targets) do
            if t[method] then
                result = t[method](...)
            end
        end
        return result
    end

    multi.write = function(s) return callAll("write", s) end
    multi.clear = function() return callAll("clear") end
    multi.setCursorPos = function(x, y) return callAll("setCursorPos", x, y) end
    multi.getCursorPos = function() return targets[1].getCursorPos() end
    multi.setTextColor = function(c) return callAll("setTextColor", c) end
    multi.setBackgroundColor = function(c) return callAll("setBackgroundColor", c) end
    multi.getTextColor = function() return targets[1].getTextColor() end
    multi.getBackgroundColor = function() return targets[1].getBackgroundColor() end
    multi.getSize = function() return w, h end
    multi.isColor = function() return targets[1].isColor() end
    multi.isColour = multi.isColor
    multi.scroll = function(n) return callAll("scroll", n) end
    multi.setCursorBlink = function(b) return callAll("setCursorBlink", b) end
    multi.getCursorBlink = function() return targets[1].getCursorBlink() end
    multi.setTextScale = function(s) return callAll("setTextScale", s) end

    if targets[1].blit then
        multi.blit = function(t, f, b) return callAll("blit", t, f, b) end
    end
    if targets[1].getLine then
        multi.getLine = function(y) return targets[1].getLine(y) end
    end

    return multi
end

function M.enableMirror()
    if not M.primaryMonitor then return false end
    M.mirrorMode = true
    local targets = { term.native(), M.primaryMonitor.wrap }
    local multi = M.createMultiTerm(targets)
    term.redirect(multi)
    return true
end

function M.disableMirror()
    M.mirrorMode = false
    term.redirect(term.native())
end

-- ============================================================
-- Touch Input Routing
-- ============================================================

function M.waitForInput(timeout)
    local timer = timeout and os.startTimer(timeout) or nil
    while true do
        local ev = {os.pullEvent()}
        if ev[1] == "key" or ev[1] == "char" or ev[1] == "key_up" then
            return ev
        elseif ev[1] == "mouse_click" or ev[1] == "mouse_scroll" then
            return ev
        elseif ev[1] == "monitor_touch" then
            -- Convert monitor_touch to mouse_click for unified handling
            return {"mouse_click", 1, ev[3], ev[4], monitor = ev[2]}
        elseif ev[1] == "timer" and ev[2] == timer then
            return {"timeout"}
        end
    end
end

-- ============================================================
-- Layout Calculation
-- ============================================================

M.LAYOUT_MODES = {"auto", "split", "grid", "tabs", "focus"}

function M.calculateLayout(modules, screenW, screenH, mode)
    mode = mode or "auto"
    local count = #modules
    local layout = { panels = {}, mode = mode }
    local usableH = screenH - 2  -- reserve header + footer

    if count == 0 then
        return layout
    end

    if mode == "tabs" or (mode == "auto" and count > 6) then
        -- Each module gets full screen, tab key cycles
        layout.mode = "tabs"
        for i, mod in ipairs(modules) do
            layout.panels[i] = { x = 1, y = 2, w = screenW, h = usableH, module = mod, visible = (i == 1) }
        end
        return layout
    end

    if mode == "focus" or (mode == "auto" and count >= 5) then
        -- First module large, rest in sidebar
        layout.mode = "focus"
        local sideW = math.max(15, math.floor(screenW * 0.3))
        local mainW = screenW - sideW
        layout.panels[1] = { x = 1, y = 2, w = mainW, h = usableH, module = modules[1], visible = true }
        local sideH = math.floor(usableH / (count - 1))
        for i = 2, count do
            layout.panels[i] = {
                x = mainW + 1, y = 2 + (i-2) * sideH,
                w = sideW, h = sideH,
                module = modules[i], visible = true
            }
        end
        return layout
    end

    if count == 1 then
        layout.panels[1] = { x = 1, y = 2, w = screenW, h = usableH, module = modules[1], visible = true }

    elseif count == 2 then
        if mode == "split" or (mode == "auto" and screenW >= 40) then
            local halfW = math.floor(screenW / 2)
            layout.panels[1] = { x = 1, y = 2, w = halfW, h = usableH, module = modules[1], visible = true }
            layout.panels[2] = { x = halfW + 1, y = 2, w = screenW - halfW, h = usableH, module = modules[2], visible = true }
        else
            local halfH = math.floor(usableH / 2)
            layout.panels[1] = { x = 1, y = 2, w = screenW, h = halfH, module = modules[1], visible = true }
            layout.panels[2] = { x = 1, y = 2 + halfH, w = screenW, h = usableH - halfH, module = modules[2], visible = true }
        end

    elseif count == 3 then
        local halfW = math.floor(screenW / 2)
        local halfH = math.floor(usableH / 2)
        layout.panels[1] = { x = 1, y = 2, w = halfW, h = usableH, module = modules[1], visible = true }
        layout.panels[2] = { x = halfW + 1, y = 2, w = screenW - halfW, h = halfH, module = modules[2], visible = true }
        layout.panels[3] = { x = halfW + 1, y = 2 + halfH, w = screenW - halfW, h = usableH - halfH, module = modules[3], visible = true }

    elseif count == 4 then
        local halfW = math.floor(screenW / 2)
        local halfH = math.floor(usableH / 2)
        layout.panels[1] = { x = 1, y = 2, w = halfW, h = halfH, module = modules[1], visible = true }
        layout.panels[2] = { x = halfW + 1, y = 2, w = screenW - halfW, h = halfH, module = modules[2], visible = true }
        layout.panels[3] = { x = 1, y = 2 + halfH, w = halfW, h = usableH - halfH, module = modules[3], visible = true }
        layout.panels[4] = { x = halfW + 1, y = 2 + halfH, w = screenW - halfW, h = usableH - halfH, module = modules[4], visible = true }

    else
        -- Grid layout for 5-8
        local cols = screenW >= 50 and 3 or 2
        local rows = math.ceil(count / cols)
        local cellW = math.floor(screenW / cols)
        local cellH = math.floor(usableH / rows)
        for i, mod in ipairs(modules) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            layout.panels[i] = {
                x = col * cellW + 1, y = 2 + row * cellH,
                w = cellW, h = cellH,
                module = mod, visible = true
            }
        end
    end

    layout.mode = mode == "auto" and (count <= 4 and "grid" or "focus") or mode
    return layout
end

-- ============================================================
-- Size Classification
-- ============================================================

function M.getMonitorClass()
    if not M.primaryMonitor then return "none" end
    local w, h = M.primaryMonitor.wrap.getSize()
    local area = w * h
    if area >= 300 then return "large"      -- 3x3+
    elseif area >= 120 then return "medium"  -- 2x2, 3x2
    else return "small" end                  -- 1x1, 2x1
end

function M.getTerminalClass()
    local w, h = term.getSize()
    if w >= 50 then return "full"           -- standard computer
    elseif w >= 26 then return "pocket"     -- pocket computer
    else return "tiny" end
end

return M
