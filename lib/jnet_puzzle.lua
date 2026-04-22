-- jnet_puzzle.lua
-- Puzzle engine for Javanet hacking/defense gameplay.
-- Generates, renders, validates puzzles for tiers 1-5.
-- Place at /lib/jnet_puzzle.lua on every Javanet computer.

local ui = require("lib.jnet_ui")
local M = {}

-- ============================================================
-- Puzzle Registry
-- ============================================================

M.puzzleTypes = {}

function M.register(name, def)
    M.puzzleTypes[name] = def
end

-- ============================================================
-- Core API
-- ============================================================

function M.generate(tier, opts)
    opts = opts or {}
    tier = math.max(1, math.min(5, tier))

    local typeName
    if tier == 1 then typeName = "pattern_match"
    elseif tier == 2 then typeName = "port_sequence"
    elseif tier == 3 then typeName = "signal_router"
    elseif tier == 4 then typeName = "cipher_crack"
    elseif tier == 5 then typeName = "system_siege"
    end

    local puzzleType = M.puzzleTypes[typeName]
    if not puzzleType then return nil, "Unknown puzzle type" end

    local puzzle = puzzleType.generate(tier, opts)
    puzzle.tier = tier
    puzzle.typeName = typeName
    puzzle.target = opts.target or "UNKNOWN"
    puzzle.timeLimit = opts.timeLimit or puzzle.timeLimit
    puzzle.maxAttempts = opts.attempts or puzzle.maxAttempts
    puzzle.attemptsUsed = 0
    puzzle.startTime = nil
    puzzle.modifier = opts.modifier
    puzzle.isDefense = opts.isDefense or false

    -- Apply modifiers from defense
    if puzzle.modifier then
        if puzzle.modifier == "time_pressure" and puzzle.timeLimit then
            puzzle.timeLimit = math.floor(puzzle.timeLimit * 0.75)
        elseif puzzle.modifier == "reduced_attempts" then
            puzzle.maxAttempts = math.max(1, puzzle.maxAttempts - 1)
        end
    end

    return puzzle
end

function M.run(puzzle)
    if not puzzle then return { success = false, reason = "no_puzzle" } end
    local puzzleType = M.puzzleTypes[puzzle.typeName]
    if not puzzleType then return { success = false, reason = "unknown_type" } end

    puzzle.startTime = os.epoch("utc") / 1000
    local W, H = ui.getSize()

    while true do
        -- Render
        ui.clear()
        M.drawFrame(puzzle)
        puzzleType.render(puzzle)

        -- Handle input
        local ev = {os.pullEvent()}

        -- Check timeout
        if puzzle.timeLimit then
            local elapsed = os.epoch("utc") / 1000 - puzzle.startTime
            if elapsed >= puzzle.timeLimit then
                return {
                    success = false,
                    reason = "timeout",
                    time = elapsed,
                    attempts_used = puzzle.attemptsUsed,
                }
            end
        end

        local result = puzzleType.handleInput(puzzle, ev)
        if result then
            if result == "correct" then
                M.drawSuccess(puzzle)
                return {
                    success = true,
                    time = os.epoch("utc") / 1000 - puzzle.startTime,
                    attempts_used = puzzle.attemptsUsed,
                }
            elseif result == "wrong" then
                puzzle.attemptsUsed = puzzle.attemptsUsed + 1
                if puzzle.attemptsUsed >= puzzle.maxAttempts then
                    M.drawFailure(puzzle)
                    return {
                        success = false,
                        reason = "max_attempts",
                        time = os.epoch("utc") / 1000 - puzzle.startTime,
                        attempts_used = puzzle.attemptsUsed,
                    }
                end
                M.drawWrong(puzzle)
            elseif result == "abort" then
                return {
                    success = false,
                    reason = "aborted",
                    time = os.epoch("utc") / 1000 - puzzle.startTime,
                    attempts_used = puzzle.attemptsUsed,
                }
            end
        end
    end
end

-- ============================================================
-- Puzzle UI Frame
-- ============================================================

function M.drawFrame(puzzle)
    local W, H = ui.getSize()
    local domain = puzzle.isDefense and "defense" or "offense"
    local title = puzzle.isDefense and "COUNTER-HACK" or "SYSTEM BREACH"

    ui.header(title, "TIER " .. puzzle.tier)

    -- Target info
    ui.write(2, 2, "Target: ", ui.DIM, ui.BG)
    ui.write(10, 2, puzzle.target, ui.ACCENT, ui.BG)

    -- Timer
    if puzzle.timeLimit then
        local elapsed = os.epoch("utc") / 1000 - (puzzle.startTime or os.epoch("utc") / 1000)
        local remaining = math.max(0, puzzle.timeLimit - elapsed)
        local timeStr = ui.formatTime(math.ceil(remaining))
        local timeColor = remaining < 10 and ui.ERR or (remaining < 30 and ui.WARN or ui.OK)
        ui.write(W - #timeStr - 1, 2, timeStr, timeColor, ui.BG)
    end

    -- Attempts
    local attStr = "ATT: " .. (puzzle.maxAttempts - puzzle.attemptsUsed) .. "/" .. puzzle.maxAttempts
    ui.write(W - #attStr - 1, H, attStr, ui.DIM, ui.BG)
end

function M.drawSuccess(puzzle)
    local W, H = ui.getSize()
    local elapsed = os.epoch("utc") / 1000 - puzzle.startTime
    ui.clear()
    ui.fillRect(1, 1, W, H, " ", nil, ui.BG)
    ui.centerWrite(math.floor(H/2) - 1, "ACCESS GRANTED", ui.OK, ui.BG)
    ui.centerWrite(math.floor(H/2) + 1, string.format("Time: %s", ui.formatTime(math.ceil(elapsed))), ui.DIM, ui.BG)
    sleep(1.5)
end

function M.drawFailure(puzzle)
    local W, H = ui.getSize()
    ui.clear()
    ui.centerWrite(math.floor(H/2) - 1, "ACCESS DENIED", ui.ERR, ui.BG)
    ui.centerWrite(math.floor(H/2) + 1, "Maximum attempts exceeded", ui.DIM, ui.BG)
    sleep(1.5)
end

function M.drawWrong(puzzle)
    local W, H = ui.getSize()
    local remaining = puzzle.maxAttempts - puzzle.attemptsUsed
    ui.centerWrite(H - 1, "INCORRECT - " .. remaining .. " attempt(s) remaining", ui.ERR, ui.BG)
    sleep(0.8)
end

-- ============================================================
-- TIER 1: Pattern Match
-- ============================================================

M.register("pattern_match", {
    tiers = {1},

    generate = function(tier, opts)
        local patterns = {}
        local patternType = math.random(3)

        if patternType == 1 then
            -- Repeating sequence: A B A B A B ??
            local symbols = {"##", "[]", "<>", "()", "{}"}
            local a, b = symbols[math.random(#symbols)], symbols[math.random(#symbols)]
            while b == a do b = symbols[math.random(#symbols)] end
            local len = math.random(5, 7)
            for i = 1, len do
                patterns[i] = (i % 2 == 1) and a or b
            end
            return {
                sequence = patterns,
                answer = (len + 1) % 2 == 1 and a or b,
                options = {a, b},
                question = "What comes next?",
                timeLimit = 30,
                maxAttempts = 5,
                selected = 1,
            }

        elseif patternType == 2 then
            -- Odd one out
            local base = math.random(1, 9)
            local positions = {}
            for i = 1, 6 do positions[i] = base end
            local oddPos = math.random(6)
            local oddVal = base + math.random(1, 3) * (math.random(2) == 1 and 1 or -1)
            if oddVal < 1 then oddVal = base + 2 end
            positions[oddPos] = oddVal
            return {
                sequence = positions,
                answer = oddPos,
                question = "Which one is different? (1-6)",
                timeLimit = 20,
                maxAttempts = 5,
                inputBuffer = "",
            }

        else
            -- Color sequence
            local colorSeq = {"R", "G", "B"}
            local seq = {}
            for i = 1, 6 do seq[i] = colorSeq[((i-1) % 3) + 1] end
            return {
                sequence = seq,
                answer = colorSeq[(6 % 3) + 1],
                options = colorSeq,
                question = "Next in sequence?",
                timeLimit = 25,
                maxAttempts = 5,
                selected = 1,
            }
        end
    end,

    render = function(puzzle)
        local W, H = ui.getSize()
        local startY = math.floor(H / 2) - 2

        -- Draw sequence
        local seqStr = ""
        for i, s in ipairs(puzzle.sequence) do
            seqStr = seqStr .. tostring(s) .. " "
        end
        seqStr = seqStr .. "??"
        ui.centerWrite(startY, seqStr, ui.FG, ui.BG)
        ui.centerWrite(startY + 1, "", ui.DIM, ui.BG)

        -- Question
        ui.centerWrite(startY + 2, puzzle.question, ui.ACCENT, ui.BG)

        -- Options or input
        if puzzle.options then
            local optStr = ""
            for i, opt in ipairs(puzzle.options) do
                if i == puzzle.selected then
                    optStr = optStr .. " [" .. opt .. "] "
                else
                    optStr = optStr .. "  " .. opt .. "  "
                end
            end
            ui.centerWrite(startY + 4, optStr, ui.FG, ui.BG)
            ui.centerWrite(startY + 6, "[LEFT/RIGHT] Select  [ENTER] Submit", ui.DIM, ui.BG)
        else
            ui.centerWrite(startY + 4, "Answer: " .. (puzzle.inputBuffer or ""), ui.ACCENT, ui.BG)
            ui.centerWrite(startY + 6, "Type your answer and press ENTER", ui.DIM, ui.BG)
        end
    end,

    handleInput = function(puzzle, ev)
        if ev[1] == "key" then
            if puzzle.options then
                if ev[2] == keys.left then
                    puzzle.selected = puzzle.selected - 1
                    if puzzle.selected < 1 then puzzle.selected = #puzzle.options end
                elseif ev[2] == keys.right then
                    puzzle.selected = puzzle.selected + 1
                    if puzzle.selected > #puzzle.options then puzzle.selected = 1 end
                elseif ev[2] == keys.enter then
                    if puzzle.options[puzzle.selected] == puzzle.answer then
                        return "correct"
                    else
                        return "wrong"
                    end
                elseif ev[2] == keys.backspace then
                    return "abort"
                end
            else
                if ev[2] == keys.enter then
                    local input = puzzle.inputBuffer or ""
                    if tonumber(input) == puzzle.answer or input == tostring(puzzle.answer) then
                        return "correct"
                    else
                        return "wrong"
                    end
                elseif ev[2] == keys.backspace then
                    if puzzle.inputBuffer and #puzzle.inputBuffer > 0 then
                        puzzle.inputBuffer = puzzle.inputBuffer:sub(1, -2)
                    else
                        return "abort"
                    end
                end
            end
        elseif ev[1] == "char" and not puzzle.options then
            puzzle.inputBuffer = (puzzle.inputBuffer or "") .. ev[2]
        end
        return nil
    end,
})

-- ============================================================
-- TIER 2: Port Sequence
-- ============================================================

M.register("port_sequence", {
    tiers = {2},

    generate = function(tier, opts)
        local ruleType = math.random(4)
        local sequence = {}
        local missingPos
        local answer

        if ruleType == 1 then
            -- Arithmetic: a, a+d, a+2d, ...
            local a = math.random(1, 10)
            local d = math.random(2, 7)
            for i = 1, 6 do sequence[i] = a + (i-1) * d end
        elseif ruleType == 2 then
            -- Geometric-ish: each = prev * 2 + 1
            local a = math.random(1, 4)
            sequence[1] = a
            for i = 2, 6 do sequence[i] = sequence[i-1] * 2 + 1 end
        elseif ruleType == 3 then
            -- Fibonacci-like: each = prev + prevprev
            sequence[1] = math.random(1, 5)
            sequence[2] = math.random(1, 5)
            for i = 3, 6 do sequence[i] = sequence[i-1] + sequence[i-2] end
        else
            -- Powers: 2^n, 3^n, etc
            local base = math.random(2, 3)
            for i = 1, 6 do sequence[i] = base ^ i end
        end

        missingPos = math.random(2, 5) -- never first or last
        answer = sequence[missingPos]
        local display = {}
        for i, v in ipairs(sequence) do
            if i == missingPos then
                display[i] = "??"
            else
                display[i] = tostring(math.floor(v))
            end
        end

        return {
            display = display,
            sequence = sequence,
            missingPos = missingPos,
            answer = math.floor(answer),
            inputBuffer = "",
            timeLimit = 60,
            maxAttempts = 3,
        }
    end,

    render = function(puzzle)
        local W, H = ui.getSize()
        local startY = math.floor(H / 2) - 3

        ui.centerWrite(startY, "CRACK THE PORT SEQUENCE", ui.FG, ui.BG)
        ui.centerWrite(startY + 1, string.rep("-", 30), ui.DIM, ui.BG)

        -- Draw boxes for each number
        local boxW = 6
        local totalW = #puzzle.display * (boxW + 1) - 1
        local startX = math.floor((W - totalW) / 2) + 1

        for i, val in ipairs(puzzle.display) do
            local bx = startX + (i - 1) * (boxW + 1)
            local isMissing = (i == puzzle.missingPos)
            local borderCol = isMissing and ui.WARN or ui.DIM
            ui.write(bx, startY + 3, "+" .. string.rep("-", boxW - 2) .. "+", borderCol, ui.BG)
            local displayVal = isMissing and "??" or val
            local padding = boxW - 2 - #displayVal
            local lpad = math.floor(padding / 2)
            local valStr = string.rep(" ", lpad) .. displayVal .. string.rep(" ", padding - lpad)
            local valCol = isMissing and ui.WARN or ui.FG
            ui.write(bx, startY + 4, "|" .. valStr .. "|", borderCol, ui.BG)
            ui.write(bx + 1, startY + 4, valStr, valCol, ui.BG)
            ui.write(bx, startY + 5, "+" .. string.rep("-", boxW - 2) .. "+", borderCol, ui.BG)
        end

        -- Input
        ui.centerWrite(startY + 8, "Enter missing value: " .. puzzle.inputBuffer .. "_", ui.ACCENT, ui.BG)
        ui.centerWrite(startY + 10, "[ENTER] Submit  [BACKSPACE] Delete", ui.DIM, ui.BG)
    end,

    handleInput = function(puzzle, ev)
        if ev[1] == "key" then
            if ev[2] == keys.enter then
                local val = tonumber(puzzle.inputBuffer)
                if val and val == puzzle.answer then
                    return "correct"
                else
                    puzzle.inputBuffer = ""
                    return "wrong"
                end
            elseif ev[2] == keys.backspace then
                if #puzzle.inputBuffer > 0 then
                    puzzle.inputBuffer = puzzle.inputBuffer:sub(1, -2)
                else
                    return "abort"
                end
            end
        elseif ev[1] == "char" then
            if ev[2]:match("[0-9]") and #puzzle.inputBuffer < 8 then
                puzzle.inputBuffer = puzzle.inputBuffer .. ev[2]
            end
        end
        return nil
    end,
})

-- ============================================================
-- TIER 3: Signal Router
-- ============================================================

M.register("signal_router", {
    tiers = {3, 4, 5},

    generate = function(tier, opts)
        local stages = tier == 3 and 3 or (tier == 4 and 2 or 1)
        local puzzleStages = {}

        for s = 1, stages do
            local nodeCount = 3 + s
            local gates = {}
            local solution = {}
            for i = 1, nodeCount do
                gates[i] = false
                solution[i] = math.random(2) == 1
            end
            puzzleStages[s] = {
                gates = gates,
                solution = solution,
                nodeCount = nodeCount,
            }
        end

        return {
            stages = puzzleStages,
            currentStage = 1,
            totalStages = stages,
            selected = 1,
            timeLimit = tier == 3 and 180 or (tier == 4 and 120 or 60),
            maxAttempts = 3,
        }
    end,

    render = function(puzzle)
        local W, H = ui.getSize()
        local stage = puzzle.stages[puzzle.currentStage]
        local startY = 4

        ui.centerWrite(3, "ROUTE THE SIGNAL: IN -> OUT", ui.FG, ui.BG)
        ui.centerWrite(startY, "Stage " .. puzzle.currentStage .. "/" .. puzzle.totalStages, ui.DIM, ui.BG)
        startY = startY + 1

        -- Draw gate nodes
        local nodeW = 6
        local totalW = stage.nodeCount * (nodeW + 1) - 1
        local startX = math.floor((W - totalW) / 2) + 1

        ui.write(2, startY + 2, "IN >>", ui.OK, ui.BG)
        ui.write(W - 5, startY + 2, ">> OUT", ui.OK, ui.BG)

        for i = 1, stage.nodeCount do
            local gx = startX + (i - 1) * (nodeW + 1)
            local gy = startY + 1
            local isOpen = stage.gates[i]
            local isSel = (i == puzzle.selected)

            local borderCol = isSel and ui.ACCENT or ui.DIM
            local label = string.char(64 + i) -- A, B, C, ...
            local stateStr = isOpen and " ON " or " OFF"
            local stateCol = isOpen and ui.OK or ui.ERR

            ui.write(gx, gy, "+" .. string.rep("-", nodeW - 2) .. "+", borderCol, ui.BG)
            ui.write(gx, gy + 1, "|", borderCol, ui.BG)
            ui.write(gx + 1, gy + 1, " " .. label .. "  ", ui.FG, ui.BG)
            ui.write(gx + nodeW - 1, gy + 1, "|", borderCol, ui.BG)
            ui.write(gx, gy + 2, "|", borderCol, ui.BG)
            ui.write(gx + 1, gy + 2, stateStr, stateCol, ui.BG)
            ui.write(gx + nodeW - 1, gy + 2, "|", borderCol, ui.BG)
            ui.write(gx, gy + 3, "+" .. string.rep("-", nodeW - 2) .. "+", borderCol, ui.BG)

            -- Connection lines
            if i < stage.nodeCount then
                ui.write(gx + nodeW, gy + 2, "-", ui.DIM, ui.BG)
            end
        end

        -- Instructions
        ui.centerWrite(startY + 7, "[LEFT/RIGHT] Select  [SPACE] Toggle  [ENTER] Submit", ui.DIM, ui.BG)

        -- Status
        local activeStr = "Active: "
        for i = 1, stage.nodeCount do
            local label = string.char(64 + i)
            activeStr = activeStr .. (stage.gates[i] and ("[" .. label .. "]") or (" " .. label .. " ")) .. " "
        end
        ui.centerWrite(startY + 9, activeStr, ui.FG, ui.BG)
    end,

    handleInput = function(puzzle, ev)
        local stage = puzzle.stages[puzzle.currentStage]
        if ev[1] == "key" then
            if ev[2] == keys.left then
                puzzle.selected = puzzle.selected - 1
                if puzzle.selected < 1 then puzzle.selected = stage.nodeCount end
            elseif ev[2] == keys.right then
                puzzle.selected = puzzle.selected + 1
                if puzzle.selected > stage.nodeCount then puzzle.selected = 1 end
            elseif ev[2] == keys.space then
                stage.gates[puzzle.selected] = not stage.gates[puzzle.selected]
            elseif ev[2] == keys.enter then
                -- Check solution
                local correct = true
                for i = 1, stage.nodeCount do
                    if stage.gates[i] ~= stage.solution[i] then
                        correct = false
                        break
                    end
                end
                if correct then
                    if puzzle.currentStage >= puzzle.totalStages then
                        return "correct"
                    else
                        puzzle.currentStage = puzzle.currentStage + 1
                        puzzle.selected = 1
                    end
                else
                    return "wrong"
                end
            elseif ev[2] == keys.backspace then
                return "abort"
            end
        end
        return nil
    end,
})

-- ============================================================
-- TIER 4: Cipher Crack
-- ============================================================

M.register("cipher_crack", {
    tiers = {4, 5},

    generate = function(tier, opts)
        -- Caesar cipher with known shift
        local words = {
            "HELLO WORLD", "ACCESS GRANTED", "OPEN SESAME", "SECURE LINK",
            "MASTER KEY", "PRIME ACCESS", "GOLD ENTRY", "IRON GATE",
            "STEEL VAULT", "DELTA FORCE", "ALPHA TEAM", "GHOST RECON",
            "NIGHT HAWK", "DARK STORM", "BLUE SHIFT", "RED DAWN",
        }
        local plaintext = words[math.random(#words)]
        local shift = math.random(1, 25)
        local ciphertext = ""
        for i = 1, #plaintext do
            local c = plaintext:byte(i)
            if c >= 65 and c <= 90 then
                ciphertext = ciphertext .. string.char(((c - 65 + shift) % 26) + 65)
            else
                ciphertext = ciphertext .. plaintext:sub(i, i)
            end
        end

        -- Hint
        local hints = {
            "Common greeting", "Permission phrase", "Entry command",
            "Network term", "Security phrase", "Military unit",
        }

        return {
            ciphertext = ciphertext,
            plaintext = plaintext,
            shift = shift,
            hint = hints[math.random(#hints)],
            inputBuffer = "",
            showFreq = false,
            timeLimit = tier == 4 and 300 or 180,
            maxAttempts = 2,
        }
    end,

    render = function(puzzle)
        local W, H = ui.getSize()
        local startY = 4

        ui.centerWrite(3, "CIPHER CRACK", ui.FG, ui.BG)

        ui.write(2, startY, "Encrypted: ", ui.DIM, ui.BG)
        ui.write(13, startY, puzzle.ciphertext, ui.WARN, ui.BG)

        ui.write(2, startY + 2, "Known shift: +" .. puzzle.shift, ui.OK, ui.BG)
        ui.write(2, startY + 3, "Hint: " .. puzzle.hint, ui.DIM, ui.BG)

        -- Frequency analysis tool
        if puzzle.showFreq then
            local freq = {}
            for i = 1, #puzzle.ciphertext do
                local c = puzzle.ciphertext:sub(i, i)
                if c:match("[A-Z]") then
                    freq[c] = (freq[c] or 0) + 1
                end
            end
            local sorted = {}
            for c, n in pairs(freq) do sorted[#sorted+1] = {c = c, n = n} end
            table.sort(sorted, function(a, b) return a.n > b.n end)

            ui.write(2, startY + 5, "Frequency:", ui.DIM, ui.BG)
            local fx = 13
            for _, entry in ipairs(sorted) do
                if fx + 4 > W then break end
                ui.write(fx, startY + 5, entry.c .. ":" .. entry.n .. " ", ui.FG, ui.BG)
                fx = fx + 4
            end
        end

        -- Input
        local inputY = startY + 7
        ui.write(2, inputY, "Decrypt: ", ui.FG, ui.BG)
        ui.write(11, inputY, puzzle.inputBuffer .. "_", ui.ACCENT, ui.BG)

        ui.centerWrite(inputY + 2, "[ENTER] Submit  [TAB] Frequency tool  [BKSP] Delete", ui.DIM, ui.BG)
    end,

    handleInput = function(puzzle, ev)
        if ev[1] == "key" then
            if ev[2] == keys.enter then
                if puzzle.inputBuffer:upper() == puzzle.plaintext then
                    return "correct"
                else
                    puzzle.inputBuffer = ""
                    return "wrong"
                end
            elseif ev[2] == keys.backspace then
                if #puzzle.inputBuffer > 0 then
                    puzzle.inputBuffer = puzzle.inputBuffer:sub(1, -2)
                else
                    return "abort"
                end
            elseif ev[2] == keys.tab then
                puzzle.showFreq = not puzzle.showFreq
            end
        elseif ev[1] == "char" then
            if #puzzle.inputBuffer < 30 then
                puzzle.inputBuffer = puzzle.inputBuffer .. ev[2]:upper()
            end
        end
        return nil
    end,
})

-- ============================================================
-- TIER 5: System Siege (multi-phase)
-- ============================================================

M.register("system_siege", {
    tiers = {5},

    generate = function(tier, opts)
        -- Generate sub-puzzles for each phase
        local phases = {}

        -- Phase 1: Port Sequence (Tier 2)
        phases[1] = M.puzzleTypes.port_sequence.generate(2, opts)
        phases[1].phaseName = "OUTER FIREWALL"

        -- Phase 2: Signal Router (Tier 3)
        phases[2] = M.puzzleTypes.signal_router.generate(3, opts)
        phases[2].phaseName = "INNER FIREWALL"

        -- Phase 3: Cipher Crack (Tier 4)
        phases[3] = M.puzzleTypes.cipher_crack.generate(4, opts)
        phases[3].phaseName = "CORE ENCRYPTION"

        return {
            phases = phases,
            currentPhase = 1,
            totalPhases = 3,
            timeLimit = 600,
            maxAttempts = 1, -- per phase, full reset on fail
            phaseAttempts = 0,
        }
    end,

    render = function(puzzle)
        local W, H = ui.getSize()
        local phase = puzzle.phases[puzzle.currentPhase]

        -- Phase indicator
        ui.write(2, 3, "SIEGE PHASE " .. puzzle.currentPhase .. "/" .. puzzle.totalPhases .. ": " .. phase.phaseName, ui.WARN, ui.BG)

        -- Progress bar
        local pct = (puzzle.currentPhase - 1) / puzzle.totalPhases
        ui.progressBar(2, H - 2, W - 2, pct, ui.OK, ui.DIM, "bracket")

        -- Render the sub-puzzle
        local subType = nil
        if puzzle.currentPhase == 1 then subType = M.puzzleTypes.port_sequence
        elseif puzzle.currentPhase == 2 then subType = M.puzzleTypes.signal_router
        elseif puzzle.currentPhase == 3 then subType = M.puzzleTypes.cipher_crack
        end
        if subType then subType.render(phase) end
    end,

    handleInput = function(puzzle, ev)
        local phase = puzzle.phases[puzzle.currentPhase]
        local subType = nil
        if puzzle.currentPhase == 1 then subType = M.puzzleTypes.port_sequence
        elseif puzzle.currentPhase == 2 then subType = M.puzzleTypes.signal_router
        elseif puzzle.currentPhase == 3 then subType = M.puzzleTypes.cipher_crack
        end

        if not subType then return "abort" end

        local result = subType.handleInput(phase, ev)
        if result == "correct" then
            if puzzle.currentPhase >= puzzle.totalPhases then
                return "correct"
            else
                puzzle.currentPhase = puzzle.currentPhase + 1
                -- Brief phase transition
                ui.clear()
                ui.centerWrite(math.floor(ui.getSize() / 2), "PHASE " .. (puzzle.currentPhase) .. " - " .. puzzle.phases[puzzle.currentPhase].phaseName, ui.WARN, ui.BG)
                sleep(1)
            end
        elseif result == "wrong" then
            -- Full reset on any failure
            puzzle.currentPhase = 1
            -- Regenerate all phases
            puzzle.phases[1] = M.puzzleTypes.port_sequence.generate(2, {})
            puzzle.phases[1].phaseName = "OUTER FIREWALL"
            puzzle.phases[2] = M.puzzleTypes.signal_router.generate(3, {})
            puzzle.phases[2].phaseName = "INNER FIREWALL"
            puzzle.phases[3] = M.puzzleTypes.cipher_crack.generate(4, {})
            puzzle.phases[3].phaseName = "CORE ENCRYPTION"
            return "wrong"
        elseif result == "abort" then
            return "abort"
        end
        return nil
    end,
})

return M
