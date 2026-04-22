-- jnet_gpu.lua
-- Module cache: return existing instance if already loaded
if _JNET_LOADED and _JNET_LOADED["jnet_gpu"] then return _JNET_LOADED["jnet_gpu"] end
if not _JNET_LOADED then _JNET_LOADED = {} end
-- DirectGPU wrapper for Javanet terminals.
-- Provides GPU-accelerated rendering when available,
-- with automatic fallback to monitor/term.
-- Place at /lib/jnet_gpu.lua on computers with DirectGPU.

local M = {}

M.gpu = nil
M.canvas = nil
M.hasGPU = false
M.width = 0
M.height = 0

-- ============================================================
-- Color Mapping (CC:T colors to RGB for GPU)
-- ============================================================

M.RGB = {
    [colors.white]     = {0xF0, 0xF0, 0xF0},
    [colors.orange]    = {0xF2, 0xB2, 0x33},
    [colors.magenta]   = {0xE5, 0x7F, 0xD8},
    [colors.lightBlue] = {0x99, 0xB2, 0xF2},
    [colors.yellow]    = {0xDE, 0xDE, 0x6C},
    [colors.lime]      = {0x7F, 0xCC, 0x19},
    [colors.pink]      = {0xF2, 0xB2, 0xCC},
    [colors.gray]      = {0x4C, 0x4C, 0x4C},
    [colors.lightGray] = {0x99, 0x99, 0x99},
    [colors.cyan]      = {0x4C, 0x99, 0xB2},
    [colors.purple]    = {0xB2, 0x66, 0xE5},
    [colors.blue]      = {0x33, 0x66, 0xCC},
    [colors.brown]     = {0x7F, 0x66, 0x4C},
    [colors.green]     = {0x57, 0xA6, 0x4E},
    [colors.red]       = {0xCC, 0x4C, 0x4C},
    [colors.black]     = {0x19, 0x19, 0x19},
}

function M.toRGB(ccColor)
    return M.RGB[ccColor] or M.RGB[colors.white]
end

-- ============================================================
-- Initialization
-- ============================================================

function M.init()
    local ok, gpu = pcall(peripheral.find, "gpu")
    if ok and gpu then
        M.gpu = gpu
        M.hasGPU = true
        local ok2, canvas = pcall(function() return gpu.getCanvas() end)
        if ok2 and canvas then
            M.canvas = canvas
            M.width, M.height = canvas.getSize()
        end
        return true
    end
    M.hasGPU = false
    return false
end

-- ============================================================
-- Drawing Primitives (GPU mode)
-- ============================================================

function M.setColor(ccColor)
    if not M.canvas then return end
    local rgb = M.toRGB(ccColor)
    M.canvas.setColor(rgb[1], rgb[2], rgb[3])
end

function M.rect(x, y, w, h, ccColor)
    if not M.canvas then return end
    M.setColor(ccColor)
    M.canvas.fillRect(x, y, w, h)
end

function M.text(x, y, str, ccColor, scale)
    if not M.canvas then return end
    M.setColor(ccColor)
    scale = scale or 1
    M.canvas.drawText(x, y, str, scale)
end

function M.line(x1, y1, x2, y2, ccColor)
    if not M.canvas then return end
    M.setColor(ccColor)
    M.canvas.drawLine(x1, y1, x2, y2)
end

function M.pixel(x, y, ccColor)
    if not M.canvas then return end
    M.setColor(ccColor)
    M.canvas.setPixel(x, y)
end

function M.clear(ccColor)
    if not M.canvas then return end
    ccColor = ccColor or colors.black
    M.rect(0, 0, M.width, M.height, ccColor)
end

function M.flush()
    if M.gpu and M.gpu.sync then
        M.gpu.sync()
    end
end

-- ============================================================
-- High-Level Widgets (GPU mode)
-- ============================================================

function M.panel(x, y, w, h, title, bgColor, borderColor, titleColor)
    if not M.canvas then return end
    bgColor = bgColor or colors.black
    borderColor = borderColor or colors.yellow
    titleColor = titleColor or colors.white

    M.rect(x, y, w, h, bgColor)
    -- Border
    M.rect(x, y, w, 1, borderColor)
    M.rect(x, y + h - 1, w, 1, borderColor)
    M.rect(x, y, 1, h, borderColor)
    M.rect(x + w - 1, y, 1, h, borderColor)
    -- Title
    if title then
        M.text(x + 2, y, " " .. title .. " ", titleColor, 1)
    end
end

function M.bar(x, y, w, h, pct, fgColor, bgColor)
    if not M.canvas then return end
    pct = math.max(0, math.min(1, pct))
    bgColor = bgColor or colors.gray
    fgColor = fgColor or colors.lime
    M.rect(x, y, w, h, bgColor)
    local filled = math.floor(w * pct)
    if filled > 0 then
        M.rect(x, y, filled, h, fgColor)
    end
end

function M.sparkline(x, y, w, h, data, color)
    if not M.canvas then return end
    color = color or colors.lime
    if #data == 0 then return end
    local maxVal = 0
    for _, v in ipairs(data) do if v > maxVal then maxVal = v end end
    if maxVal == 0 then maxVal = 1 end
    M.setColor(color)
    local step = w / math.max(1, #data - 1)
    for i = 1, #data - 1 do
        local x1 = x + (i - 1) * step
        local y1 = y + h - (data[i] / maxVal) * h
        local x2 = x + i * step
        local y2 = y + h - (data[i+1] / maxVal) * h
        M.canvas.drawLine(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2))
    end
end

-- ============================================================
-- Fallback (returns false if no GPU, caller uses term API)
-- ============================================================

function M.available()
    return M.hasGPU and M.canvas ~= nil
end

_JNET_LOADED["jnet_gpu"] = M
return M
