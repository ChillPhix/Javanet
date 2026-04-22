-- jnet_anim.lua
-- Module cache: return existing instance if already loaded
if _JNET_LOADED and _JNET_LOADED["jnet_anim"] then return _JNET_LOADED["jnet_anim"] end
if not _JNET_LOADED then _JNET_LOADED = {} end
-- Animation library for Javanet terminals.
-- Provides reusable animation primitives for boot sequences,
-- screen transitions, glitch effects, and visual flair.
-- Place at /lib/jnet_anim.lua on every Javanet computer.

local ui = dofile("/jnet/lib/jnet_ui.lua")
local M = {}

-- ============================================================
-- Text Animations
-- ============================================================

function M.typewriter(y, text, speed, fg, bg)
    speed = speed or 0.03
    fg = fg or ui.FG
    local W = ui.getSize()
    local x = math.floor((W - #text) / 2) + 1
    for i = 1, #text do
        ui.write(x + i - 1, y, text:sub(i, i), fg, bg or ui.BG)
        if speed > 0 then sleep(speed) end
    end
end

function M.typewriterLeft(x, y, text, speed, fg)
    speed = speed or 0.03
    fg = fg or ui.FG
    for i = 1, #text do
        ui.write(x + i - 1, y, text:sub(i, i), fg, ui.BG)
        if speed > 0 then sleep(speed) end
    end
end

function M.pulseText(y, text, fg, cycles, speed)
    cycles = cycles or 3
    speed = speed or 0.15
    local W = ui.getSize()
    local x = math.floor((W - #text) / 2) + 1
    for i = 1, cycles do
        ui.write(x, y, text, fg or ui.FG, ui.BG)
        sleep(speed)
        ui.write(x, y, text, ui.DIM, ui.BG)
        sleep(speed)
    end
    ui.write(x, y, text, fg or ui.FG, ui.BG)
end

function M.flickerText(y, text, fg, count)
    count = count or 3
    local W = ui.getSize()
    local x = math.floor((W - #text) / 2) + 1
    for i = 1, count do
        ui.write(x, y, text, fg or ui.FG, ui.BG)
        sleep(0.1)
        ui.write(x, y, string.rep(" ", #text), nil, ui.BG)
        sleep(0.07)
    end
    ui.write(x, y, text, fg or ui.FG, ui.BG)
end

-- ============================================================
-- Glitch Effects
-- ============================================================

local GLITCH_CHARS = "!@#$%^&*()_+-=[]{}|;:<>?/~01ABCDEFabcdef"
local GLITCH_COLORS = {colors.red, colors.orange, colors.gray, colors.lime, colors.yellow, colors.cyan, colors.purple}

function M.glitchLine(y, duration)
    local W, H = ui.getSize()
    if y < 1 or y > H then return end
    local endTime = os.epoch("utc") / 1000 + (duration or 0.1)
    while os.epoch("utc") / 1000 < endTime do
        term.setCursorPos(1, y)
        for i = 1, W do
            term.setTextColor(GLITCH_COLORS[math.random(#GLITCH_COLORS)])
            local c = math.random(#GLITCH_CHARS)
            term.write(GLITCH_CHARS:sub(c, c))
        end
        sleep(0.05)
    end
end

function M.glitchScreen(duration, intensity)
    local W, H = ui.getSize()
    intensity = intensity or 0.3
    local endTime = os.epoch("utc") / 1000 + (duration or 0.5)
    while os.epoch("utc") / 1000 < endTime do
        for y = 1, H do
            if math.random() < intensity then
                M.glitchLine(y, 0)
            end
        end
        sleep(0.05)
    end
end

function M.glitchReveal(lines, y, duration, fg)
    duration = duration or 1.5
    fg = fg or ui.FG
    local W = ui.getSize()
    local totalChars = 0
    for _, line in ipairs(lines) do totalChars = totalChars + #line end
    local revealed = {}
    for i, line in ipairs(lines) do
        revealed[i] = {}
        for j = 1, #line do revealed[i][j] = false end
    end
    local steps = math.max(10, totalChars)
    local stepDelay = duration / steps
    local charsPerStep = math.max(1, math.ceil(totalChars / steps))
    for step = 1, steps do
        for _ = 1, charsPerStep do
            local li = math.random(#lines)
            local ci = math.random(#lines[li])
            revealed[li][ci] = true
        end
        for i, line in ipairs(lines) do
            local row = y + i - 1
            local cx = math.floor((W - #line) / 2) + 1
            for j = 1, #line do
                if revealed[i][j] then
                    ui.write(cx + j - 1, row, line:sub(j, j), fg, ui.BG)
                else
                    local gc = math.random(#GLITCH_CHARS)
                    ui.write(cx + j - 1, row, GLITCH_CHARS:sub(gc, gc),
                        GLITCH_COLORS[math.random(#GLITCH_COLORS)], ui.BG)
                end
            end
        end
        sleep(stepDelay)
    end
    -- Final clean render
    for i, line in ipairs(lines) do
        ui.centerWrite(y + i - 1, line, fg, ui.BG)
    end
end

-- ============================================================
-- Screen Effects
-- ============================================================

function M.scanline(direction, speed, color)
    local W, H = ui.getSize()
    speed = speed or 0.03
    color = color or ui.FG
    if direction == "down" or direction == nil then
        for y = 1, H do
            ui.fillLine(y, string.char(176), color, ui.BG)
            sleep(speed)
            ui.fillLine(y, " ", nil, ui.BG)
        end
    elseif direction == "up" then
        for y = H, 1, -1 do
            ui.fillLine(y, string.char(176), color, ui.BG)
            sleep(speed)
            ui.fillLine(y, " ", nil, ui.BG)
        end
    end
end

function M.matrixRain(duration, color)
    local W, H = ui.getSize()
    color = color or colors.lime
    local drops = {}
    for x = 1, W do
        drops[x] = { y = math.random(-H, 0), speed = math.random(1, 3), char = "" }
    end
    local endTime = os.epoch("utc") / 1000 + (duration or 2)
    while os.epoch("utc") / 1000 < endTime do
        for x = 1, W do
            local d = drops[x]
            d.y = d.y + d.speed
            if d.y > H + 5 then
                d.y = math.random(-5, 0)
                d.speed = math.random(1, 3)
            end
            for trail = 0, 4 do
                local ty = math.floor(d.y) - trail
                if ty >= 1 and ty <= H then
                    local gc = math.random(#GLITCH_CHARS)
                    local brightness = trail == 0 and colors.white or (trail < 2 and color or colors.gray)
                    ui.write(x, ty, GLITCH_CHARS:sub(gc, gc), brightness, ui.BG)
                end
            end
            local clearY = math.floor(d.y) - 5
            if clearY >= 1 and clearY <= H then
                ui.write(x, clearY, " ", nil, ui.BG)
            end
        end
        sleep(0.05)
    end
end

function M.flash(color, duration)
    local W, H = ui.getSize()
    color = color or colors.white
    duration = duration or 0.1
    for y = 1, H do
        ui.fillLine(y, " ", color, color)
    end
    sleep(duration)
end

function M.fadeIn(duration)
    duration = duration or 0.5
    local steps = math.max(3, math.floor(duration / 0.1))
    for i = 1, steps do
        sleep(duration / steps)
    end
end

-- ============================================================
-- Screen Transitions
-- ============================================================

function M.transition(style, duration)
    duration = duration or 0.5
    local W, H = ui.getSize()

    if style == "wipe" then
        local stepDelay = duration / W
        for x = 1, W do
            for y = 1, H do
                ui.write(x, y, " ", nil, ui.BG)
            end
            sleep(stepDelay)
        end

    elseif style == "glitch" then
        M.glitchScreen(duration * 0.7, 0.5)
        ui.clear()

    elseif style == "fade" then
        local chars = {string.char(178), string.char(177), string.char(176), " "}
        for _, ch in ipairs(chars) do
            for y = 1, H do
                ui.fillLine(y, ch, ui.DIM, ui.BG)
            end
            sleep(duration / #chars)
        end

    elseif style == "shatter" then
        local cells = {}
        for x = 1, W do
            for y = 1, H do
                cells[#cells+1] = {x = x, y = y}
            end
        end
        -- Shuffle
        for i = #cells, 2, -1 do
            local j = math.random(i)
            cells[i], cells[j] = cells[j], cells[i]
        end
        local perStep = math.max(1, math.floor(#cells / (duration / 0.02)))
        local idx = 1
        while idx <= #cells do
            for _ = 1, perStep do
                if idx > #cells then break end
                ui.write(cells[idx].x, cells[idx].y, " ", nil, ui.BG)
                idx = idx + 1
            end
            sleep(0.02)
        end

    elseif style == "scanline" then
        M.scanline("down", duration / H)

    elseif style == "none" then
        ui.clear()
    else
        ui.clear()
    end
end

-- ============================================================
-- Screen Capture & Corruption (for agent/worm payloads)
-- ============================================================

function M.captureScreen()
    local W, H = ui.getSize()
    local cap = {}
    local cur = term.current()
    for y = 1, H do
        local ok, text, fg, bg = pcall(function() return cur.getLine(y) end)
        if ok and text then
            cap[y] = { text = text, fg = fg, bg = bg }
        else
            cap[y] = { text = string.rep(" ", W), fg = string.rep("0", W), bg = string.rep("f", W) }
        end
    end
    return cap
end

function M.drawCapture(cap)
    local cur = term.current()
    for y, line in pairs(cap) do
        if cur.blit then
            cur.setCursorPos(1, y)
            cur.blit(line.text, line.fg, line.bg)
        else
            term.setCursorPos(1, y)
            term.write(line.text)
        end
    end
end

function M.corruptScreen(cap, duration, phases)
    local W, H = ui.getSize()
    phases = phases or 4
    duration = duration or 2
    local phaseTime = duration / phases

    -- Phase 1: Subtle character replacement
    M.drawCapture(cap)
    local endP1 = os.epoch("utc") / 1000 + phaseTime
    while os.epoch("utc") / 1000 < endP1 do
        local rx, ry = math.random(W), math.random(H)
        local gc = math.random(#GLITCH_CHARS)
        ui.write(rx, ry, GLITCH_CHARS:sub(gc, gc),
            GLITCH_COLORS[math.random(#GLITCH_COLORS)], ui.BG)
        sleep(0.03)
    end

    -- Phase 2: Line displacement
    local endP2 = os.epoch("utc") / 1000 + phaseTime
    while os.epoch("utc") / 1000 < endP2 do
        local ry = math.random(H)
        local offset = math.random(-5, 5)
        if cap[ry] then
            local shifted = string.rep(" ", math.max(0, offset)) .. cap[ry].text
            term.setCursorPos(1, ry)
            term.setTextColor(GLITCH_COLORS[math.random(#GLITCH_COLORS)])
            term.write(shifted:sub(1, W))
        end
        sleep(0.05)
    end

    -- Phase 3: Red flood
    local endP3 = os.epoch("utc") / 1000 + phaseTime
    while os.epoch("utc") / 1000 < endP3 do
        local ry = math.random(H)
        ui.fillLine(ry, " ", colors.red, colors.red)
        sleep(0.04)
    end

    -- Phase 4: Flash
    M.flash(colors.white, 0.15)
    M.flash(colors.red, 0.1)
    ui.clear()
end

-- ============================================================
-- Boot Sequence Builder
-- ============================================================

M.BOOT_PRESETS = {
    military = {
        transition = "wipe",
        loading_style = "modules",
        logo_reveal = "static",
        speed = "normal",
    },
    hacker = {
        transition = "glitch",
        loading_style = "hex",
        logo_reveal = "glitch_resolve",
        speed = "normal",
    },
    corporate = {
        transition = "fade",
        loading_style = "dots",
        logo_reveal = "fade",
        speed = "normal",
    },
    glitch = {
        transition = "shatter",
        loading_style = "hex",
        logo_reveal = "glitch_resolve",
        speed = "cinematic",
    },
    stealth = {
        transition = "none",
        loading_style = "none",
        logo_reveal = "none",
        speed = "fast",
    },
    retro = {
        transition = "scanline",
        loading_style = "dots",
        logo_reveal = "typewriter",
        speed = "cinematic",
    },
}

local SPEED_MULTIPLIER = {
    fast = 0.3,
    normal = 1.0,
    cinematic = 1.8,
}

function M.bootSequence(config, skipCheck)
    config = config or {}
    local preset = M.BOOT_PRESETS[config.preset or "military"] or M.BOOT_PRESETS.military
    local transition = config.transition or preset.transition
    local loadingStyle = config.loading_style or preset.loading_style
    local logoReveal = config.logo_reveal or preset.logo_reveal
    local speedName = config.speed or preset.speed
    local speed = SPEED_MULTIPLIER[speedName] or 1.0
    local skipOnCtrl = config.skip_on_ctrl ~= false

    -- Check for skip
    if skipOnCtrl and skipCheck then
        -- Allow skipping during boot
    end

    local W, H = ui.getSize()
    ui.clear()

    -- Phase 1: Logo reveal
    if logoReveal ~= "none" and ui.logoLines and #ui.logoLines > 0 then
        local logoH = #ui.logoLines
        local startY = math.max(1, math.floor((H - logoH) / 2) - 1)

        if logoReveal == "typewriter" then
            for i, line in ipairs(ui.logoLines) do
                M.typewriter(startY + i - 1, line, 0.02 * speed, ui.FG)
            end
            sleep(0.5 * speed)
        elseif logoReveal == "glitch_resolve" then
            M.glitchReveal(ui.logoLines, startY, 1.5 * speed, ui.FG)
            sleep(0.3 * speed)
        elseif logoReveal == "flash" then
            for i, line in ipairs(ui.logoLines) do
                ui.centerWrite(startY + i - 1, line, ui.FG, ui.BG)
            end
            M.flash(colors.white, 0.15)
            for i, line in ipairs(ui.logoLines) do
                ui.centerWrite(startY + i - 1, line, ui.FG, ui.BG)
            end
            sleep(0.5 * speed)
        elseif logoReveal == "static" then
            for i, line in ipairs(ui.logoLines) do
                ui.centerWrite(startY + i - 1, line, ui.FG, ui.BG)
            end
            sleep(0.8 * speed)
        elseif logoReveal == "fade" then
            for i, line in ipairs(ui.logoLines) do
                ui.centerWrite(startY + i - 1, line, ui.DIM, ui.BG)
            end
            sleep(0.3 * speed)
            for i, line in ipairs(ui.logoLines) do
                ui.centerWrite(startY + i - 1, line, ui.FG, ui.BG)
            end
            sleep(0.5 * speed)
        end
    end

    -- Phase 2: Facility name + motto
    local nameY = ui.logoLines and (math.floor((H - #ui.logoLines) / 2) + #ui.logoLines + 1) or math.floor(H / 2) - 1
    M.typewriter(nameY, ui.facilityName, 0.04 * speed, ui.ACCENT)
    if ui.facilityMotto and #ui.facilityMotto > 0 then
        sleep(0.2 * speed)
        M.typewriter(nameY + 1, ui.facilityMotto, 0.02 * speed, ui.DIM)
    end
    sleep(0.5 * speed)

    -- Phase 3: Loading sequence
    local loadY = nameY + 3
    if loadY > H - 3 then loadY = H - 3 end

    if loadingStyle == "modules" then
        local modules = config.module_names or {"Protocol", "Security", "Interface", "Network"}
        for i, mod in ipairs(modules) do
            local row = loadY + i - 1
            if row > H - 1 then break end
            M.typewriterLeft(3, row, "[  ] " .. mod .. "...", 0.02 * speed, ui.DIM)
            sleep(0.15 * speed)
            ui.write(4, row, "OK", ui.OK, ui.BG)
            sleep(0.05 * speed)
        end
        sleep(0.3 * speed)

    elseif loadingStyle == "hex" then
        local modules = config.module_names or {"protocol", "security", "interface", "network"}
        for i, mod in ipairs(modules) do
            local row = loadY + i - 1
            if row > H - 1 then break end
            local addr = string.format("0x%04X", math.random(0x1000, 0xFFFF))
            M.typewriterLeft(3, row, addr .. " Loading " .. mod .. "... OK", 0.015 * speed, ui.FG)
            sleep(0.1 * speed)
        end
        sleep(0.3 * speed)

    elseif loadingStyle == "dots" then
        ui.centerWrite(loadY, "Loading", ui.DIM, ui.BG)
        for i = 1, 12 do
            local dots = string.rep(".", (i % 4))
            ui.centerWrite(loadY, "Loading" .. dots .. "   ", ui.DIM, ui.BG)
            sleep(0.15 * speed)
        end

    elseif loadingStyle == "bar" then
        ui.centerWrite(loadY, "INITIALIZING JAVANET", ui.DIM, ui.BG)
        local barW = math.min(30, W - 6)
        local barX = math.floor((W - barW) / 2) + 1
        for pct = 0, 100, 3 do
            ui.progressBar(barX, loadY + 1, barW, pct / 100, ui.OK, ui.DIM, "bracket")
            ui.centerWrite(loadY + 2, pct .. "%", ui.DIM, ui.BG)
            sleep(0.03 * speed)
        end
        sleep(0.2 * speed)

    elseif loadingStyle ~= "none" then
        sleep(0.5 * speed)
    end

    -- Phase 4: Transition to main UI
    sleep(0.2 * speed)
    M.transition(transition, 0.4 * speed)
end

-- ============================================================
-- Lockout Animations (for payloads)
-- ============================================================

function M.lockoutReveal(factionName, motto, logoLines, fg, bg)
    fg = fg or colors.red
    bg = bg or colors.black
    local W, H = ui.getSize()
    term.setBackgroundColor(bg)
    term.clear()

    -- Glitch buildup
    M.glitchScreen(1.0, 0.4)

    -- Flash
    M.flash(fg, 0.15)
    term.setBackgroundColor(bg)
    term.clear()

    -- Logo
    if logoLines and #logoLines > 0 then
        local startY = math.max(1, math.floor((H - #logoLines) / 2) - 2)
        M.glitchReveal(logoLines, startY, 1.2, fg)
        sleep(0.3)
    end

    -- Name
    local nameY = logoLines and (math.floor((H - #logoLines) / 2) + #logoLines + 1) or math.floor(H / 2)
    M.flickerText(nameY, factionName, fg, 4)
    if motto and #motto > 0 then
        sleep(0.2)
        M.typewriter(nameY + 1, motto, 0.03, colors.gray)
    end
end

_JNET_LOADED["jnet_anim"] = M
return M
