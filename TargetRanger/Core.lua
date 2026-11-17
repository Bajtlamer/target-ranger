-- Target Ranger 0.1.7
-- Shows a range badge on the target frame and/or the target nameplate.
-- Positive number: the target is inside your attack range (number is the upper distance bound in yards).
-- Negative number: you cannot hit it (too far or too close, see the label under the number).

local TR = {}
_G.TargetRanger = TR

local DEFAULTS = {
    enabled = true,
    anchor = "both", -- target | nameplate | both | screen
    floatingText = true,
    scale = 1,
    npcs = false,        -- false: ignore NPC targets
    sameSide = false,    -- false: ignore players of your own faction or race
    log = true,          -- write diagnostics to SavedVariables (TargetRangerDB.logLines)
    inBattleground = true, -- false: addon is silent inside battlegrounds
    locked = true,
    point = { "CENTER", "UIParent", "CENTER", 0, -150 },
}

local COLORS = {
    IN = { 0.15, 1.0, 0.25 },
    CLOSE = { 1.0, 0.6, 0.1 },
    FAR = { 1.0, 0.2, 0.2 },
}

local LABELS = {
    IN = "IN RANGE",
    CLOSE = "TOO CLOSE",
    FAR = "OUT OF RANGE",
}

-- Spells used as range probes. Melee spells are deliberately not probed: their range check
-- reported "in range" at any distance on this client (see log analysis), and this addon is for ranged attacks.
-- primary = the attack the number is judged against (first known wins).
local PROBES = {
    { id = 75, primary = true, fmin = 5, fmax = 35 },   -- Auto Shot
    { id = 3044, primary = true, fmin = 5, fmax = 35 }, -- Arcane Shot
    { id = 1978, primary = true, fmin = 5, fmax = 35 }, -- Serpent Sting
    { id = 5116, fmin = 5, fmax = 35 },                 -- Concussive Shot
    { id = 1130, fmin = 0, fmax = 100 },                -- Hunter's Mark
    { id = 1513 },                                      -- Scare Beast
    { id = 19503 },                                     -- Scatter Shot
    { id = 20736 },                                     -- Distracting Shot
}

-- CheckInteractDistance fallbacks: index, yards
local INTERACT = { { 3, 9.9 }, { 2, 11.11 }, { 4, 28 } }

local db
local checkers = {}
local LOG_MAX = 1500

local function Log(text)
    if not db or not db.log then return end
    db.logLines = db.logLines or {}
    local lines = db.logLines
    lines[#lines + 1] = date("%H:%M:%S") .. " " .. text
    if #lines > LOG_MAX then table.remove(lines, 1) end
end

local function ProbeDump(unit)
    local out = {}
    for _, c in ipairs(checkers) do
        local r = c.test(unit)
        out[#out + 1] = c.name .. "=" .. (r == nil and "na" or (r and "in" or "out"))
    end
    return table.concat(out, " ")
end
local MELEE_RANGE = 5

---------------------------------------------------------------------------
-- Spell helpers (work with both the table and the multi-return GetSpellInfo)
---------------------------------------------------------------------------
local function GetSpellData(spell)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spell)
        if info then return info.name, info.minRange or 0, info.maxRange or 0, info.iconID, info.spellID end
        return nil
    end
    if GetSpellInfo then
        local name, _, icon, _, minRange, maxRange, spellID = GetSpellInfo(spell)
        if name then return name, minRange or 0, maxRange or 0, icon, spellID end
    end
end

local function IsKnown(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

local function SpellInRange(name, unit)
    local r
    if C_Spell and C_Spell.IsSpellInRange then
        r = C_Spell.IsSpellInRange(name, unit)
    elseif IsSpellInRange then
        r = IsSpellInRange(name, unit)
    end
    if r == true or r == 1 then return true end
    if r == false or r == 0 then return false end
    return nil
end

function TR.Rebuild()
    wipe(checkers)
    local seenPrimary = false
    for _, p in ipairs(PROBES) do
        local name, minR, maxR, icon, spellID = GetSpellData(p.id)
        if name and IsKnown(p.id) then
            -- Weapon attacks report range 0 in the spell data, so use the fallbacks.
            local melee = false
            local apiMin, apiMax = minR, maxR
            -- Weapon and shot ranges are unreliable in the spell data: never trust less than the fallback.
            if p.fmax and maxR < p.fmax then maxR = 0 end
            if maxR <= 0 then
                if p.melee then
                    melee, minR, maxR = true, 0, MELEE_RANGE
                elseif p.fmax then
                    minR, maxR = p.fmin or 0, p.fmax
                else
                    maxR = nil
                end
            end
            if maxR then
                local c = {
                    name = name, min = minR, max = maxR, apiMin = apiMin, apiMax = apiMax,
                    melee = melee, icon = icon,
                    primary = p.primary and not seenPrimary or false,
                }
                if c.primary then seenPrimary = true end
                c.test = function(unit) return SpellInRange(name, unit) end
                checkers[#checkers + 1] = c
            end
        end
    end
    for _, i in ipairs(INTERACT) do
        local idx, yards = i[1], i[2]
        checkers[#checkers + 1] = {
            name = "Interact" .. idx, min = 0, max = yards, interact = true,
            test = function(unit) return not not CheckInteractDistance(unit, idx) end,
        }
    end
end

---------------------------------------------------------------------------
-- Measurement
---------------------------------------------------------------------------
-- Returns state ("IN"|"CLOSE"|"FAR"), signed number, sub label
function TR.Measure(unit)
    local hi, lo = nil, 0
    local primary, primaryIn
    for _, c in ipairs(checkers) do
        local ok = c.test(unit)
        if ok ~= nil then
            if ok then
                if not hi or c.max < hi then hi = c.max end
                if c.min > lo then lo = c.min end -- a passing probe means at least its minimum range
            elseif c.min == 0 and not c.interact and c.max > lo then
                lo = c.max -- interact checks are unreliable on NPCs: only a positive answer counts
            end
            if c.primary and primaryIn == nil then primary, primaryIn = c, ok end
        end
    end
    if primaryIn == nil then primaryIn = hi ~= nil end
    local pmax = primary and primary.max or 0

    local function bound(l, h)
        if h and l > 0 then return string.format("%d-%d yd", l + 0.5, h + 0.5) end
        if h then return string.format("<= %d yd", h + 0.5) end
        return string.format("> %d yd", l + 0.5)
    end

    if primaryIn then
        local top = hi or pmax
        return "IN", math.floor(top + 0.5), bound(lo < top and lo or 0, top)
    end
    if hi and primary and primary.min > 0 and hi <= 12 then
        return "CLOSE", -math.floor(hi + 0.5), bound(0, hi)
    end
    local far = lo > pmax and lo or pmax
    return "FAR", -math.floor(far + 0.5), bound(far, hi)
end

---------------------------------------------------------------------------
-- Badge
---------------------------------------------------------------------------
local FONT = "Fonts\\FRIZQT__.TTF"
local FALLBACK_ICON = "Interface\\Icons\\Ability_Marksmanship"

local function CreateBadge(name)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(86, 34)
    f:SetFrameStrata("HIGH")
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.55)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(28, 28)
    f.icon:SetPoint("LEFT", 3, 0)
    f.icon:SetTexture(FALLBACK_ICON)
    f.number = f:CreateFontString(nil, "OVERLAY")
    f.number:SetFont(FONT, 16, "OUTLINE")
    f.number:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 4, 0)
    f.sub = f:CreateFontString(nil, "OVERLAY")
    f.sub:SetFont(FONT, 9, "OUTLINE")
    f.sub:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 4, 0)
    f:Hide()
    return f
end

local badges = {
    target = CreateBadge("TargetRangerTargetBadge"),
    plate = CreateBadge("TargetRangerPlateBadge"),
    screen = CreateBadge("TargetRangerScreenBadge"),
}

local function SetupScreenBadge()
    local f = badges.screen
    f:SetMovable(true)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        db.point = { p, "UIParent", rp, x, y }
    end)
end

local function PlaceScreenBadge()
    local p = db.point
    badges.screen:ClearAllPoints()
    badges.screen:SetPoint(p[1], UIParent, p[3], p[4], p[5])
end

local function ApplyBadge(f, state, number, sub, iconTex)
    local c = COLORS[state]
    f.number:SetText(string.format("%+d", number))
    f.number:SetTextColor(c[1], c[2], c[3])
    f.sub:SetText(sub)
    f.sub:SetTextColor(c[1], c[2], c[3])
    f.bg:SetColorTexture(c[1] * 0.25, c[2] * 0.25, c[3] * 0.25, 0.65)
    f.icon:SetTexture(iconTex or FALLBACK_ICON)
    f:SetScale(db.scale)
    f:Show()
end

local function HideAll()
    for _, f in pairs(badges) do f:Hide() end
end

local function InBattleground()
    local _, kind = IsInInstance()
    return kind == "pvp"
end

local function Eligible(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not UnitCanAttack("player", unit) then
        return false
    end
    if not db.inBattleground and InBattleground() then return false end
    if not UnitIsPlayer(unit) then return db.npcs end
    if db.sameSide then return true end
    local myFaction, theirFaction = UnitFactionGroup("player"), UnitFactionGroup(unit)
    if myFaction and theirFaction and myFaction == theirFaction then return false end
    local _, myRace = UnitRace("player")
    local _, theirRace = UnitRace(unit)
    if myRace and theirRace and myRace == theirRace then return false end
    return true
end

local function PlateFor(unit)
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        return C_NamePlate.GetNamePlateForUnit(unit)
    end
end

local function Anchor()
    local a = db.anchor
    local showTarget = (a == "target" or a == "both")
    local showPlate = (a == "nameplate" or a == "both")
    local showScreen = (a == "screen")

    if showTarget and TargetFrame and TargetFrame:IsShown() then
        badges.target:ClearAllPoints()
        badges.target:SetPoint("LEFT", TargetFrame, "RIGHT", -22, 8)
    else
        showTarget = false
    end
    local plate = showPlate and PlateFor("target")
    if plate then
        badges.plate:ClearAllPoints()
        badges.plate:SetPoint("BOTTOM", plate, "TOP", 0, 6)
    else
        showPlate = false
    end
    return showTarget, showPlate, showScreen
end

---------------------------------------------------------------------------
-- Floating text
---------------------------------------------------------------------------
local float = CreateFrame("Frame", "TargetRangerFloat", UIParent)
float:SetSize(300, 40)
float:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
float:SetFrameStrata("HIGH")
float.text = float:CreateFontString(nil, "OVERLAY")
float.text:SetFont(FONT, 26, "OUTLINE")
float.text:SetPoint("CENTER")
float:Hide()
local floatElapsed = 0
float:SetScript("OnUpdate", function(self, dt)
    floatElapsed = floatElapsed + dt
    if floatElapsed >= 1.4 then self:Hide() return end
    self:SetAlpha(floatElapsed < 0.7 and 1 or (1.4 - floatElapsed) / 0.7)
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 140 + floatElapsed * 25)
end)

local lastFloat = 0
local function Float(state)
    if not db.floatingText then return end
    local now = GetTime()
    if now - lastFloat < 0.6 then return end
    lastFloat = now
    local c = COLORS[state]
    Log("FLOAT " .. LABELS[state])
    float.text:SetText(LABELS[state])
    float.text:SetTextColor(c[1], c[2], c[3])
    floatElapsed = 0
    float:SetAlpha(1)
    float:Show()
end

---------------------------------------------------------------------------
-- Update loop
---------------------------------------------------------------------------
local lastState, pendingState, pendingTicks
local rawState, lastSample = nil, 0
local testStep, testNext = nil, 0
local TEST = {
    { "IN", 30, "5-35 yd" }, { "CLOSE", -5, "<= 5 yd" }, { "FAR", -35, "> 35 yd" }, { "IN", 8, "5-8 yd" },
}

local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    if not db or not db.enabled then HideAll() return end

    local state, number, sub
    if testStep then
        if GetTime() >= testNext then
            testStep = testStep + 1
            testNext = GetTime() + 1.6
            if testStep > #TEST then testStep = nil HideAll() lastState = nil return end
            Float(TEST[testStep][1])
        end
        local t = TEST[testStep]
        state, number, sub = t[1], t[2], t[3]
    else
        if not Eligible("target") then
            HideAll() lastState = nil pendingState = nil
            if rawState ~= "HIDDEN" then
                rawState = "HIDDEN"
                Log("HIDDEN " .. (UnitExists("target") and string.format("name=%s player=%s faction=%s race=%s canAttack=%s",
                    tostring(UnitName("target")), tostring(UnitIsPlayer("target")), tostring(UnitFactionGroup("target")),
                    tostring((select(2, UnitRace("target")))), tostring(UnitCanAttack("player", "target"))) or "no target"))
            end
            return
        end
        state, number, sub = TR.Measure("target")
        local now = GetTime()
        if state ~= rawState or now - lastSample >= 1 then
            Log(string.format("%s %s %+d (%s) | %s", state ~= rawState and "CHANGE" or "sample", state, number, sub,
                ProbeDump("target")))
            rawState, lastSample = state, now
        end
        -- debounce state changes for the floating text (2 stable ticks)
        if state ~= lastState then
            if pendingState == state then
                pendingTicks = pendingTicks + 1
                if pendingTicks >= 2 then
                    if lastState ~= nil then Float(state) end
                    lastState = state
                end
            else
                pendingState, pendingTicks = state, 1
                if lastState == nil then lastState = state end
            end
        else
            pendingState = nil
        end
    end

    local c1 = checkers[1] and checkers[1].icon
    local sT, sP, sS = Anchor()
    if testStep and not sT and not sP then sS = true end
    if sT then ApplyBadge(badges.target, state, number, sub, c1) else badges.target:Hide() end
    if sP then ApplyBadge(badges.plate, state, number, sub, c1) else badges.plate:Hide() end
    if sS then ApplyBadge(badges.screen, state, number, sub, c1) else badges.screen:Hide() end
end)

---------------------------------------------------------------------------
-- Events and slash commands
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        TargetRangerDB = TargetRangerDB or {}
        db = TargetRangerDB
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
        SetupScreenBadge()
        PlaceScreenBadge()
        TR.Rebuild()
        Log("LOGIN version 0.1.7, probes: " .. #checkers)
        for _, c in ipairs(checkers) do
            Log(string.format("PROBE %s api=%s-%s used=%s-%s primary=%s", c.name, tostring(c.apiMin),
                tostring(c.apiMax), tostring(c.min), tostring(c.max), tostring(c.primary or false)))
        end
    elseif event == "SPELLS_CHANGED" then
        if db then TR.Rebuild() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        lastState, pendingState = nil, nil
    end
end)

local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTargetRanger:|r " .. msg) end

local function Debug()
    if not UnitExists("target") then Say("No target.") return end
    Say(string.format("player=%s faction=%s race=%s canAttack=%s eligible=%s", tostring(UnitIsPlayer("target")),
        tostring(UnitFactionGroup("target")), tostring((select(2, UnitRace("target")))),
        tostring(UnitCanAttack("player", "target")), tostring(Eligible("target"))))
    Say("Log lines stored: " .. (db.logLines and #db.logLines or 0) .. ". Use /reload to flush them to disk.")
    for _, c in ipairs(checkers) do
        local r = c.test("target")
        Say(string.format("%s api=%s-%s used=%s-%s primary=%s -> %s", c.name, tostring(c.apiMin), tostring(c.apiMax),
            tostring(c.min), tostring(c.max), tostring(c.primary or false), r == nil and "n/a" or (r and "in" or "out")))
    end
    local s, n, sub = TR.Measure("target")
    Say(string.format("Result: %s %+d (%s)", s, n, sub))
end

SLASH_TARGETRANGER1 = "/ranger"
SLASH_TARGETRANGER2 = "/tr"
SlashCmdList["TARGETRANGER"] = function(msg)
    if not db then return end
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
        Say("Addon " .. cmd)
    elseif cmd == "anchor" and (arg == "target" or arg == "nameplate" or arg == "both" or arg == "screen") then
        db.anchor = arg
        Say("Anchor: " .. arg)
    elseif cmd == "text" and (arg == "on" or arg == "off") then
        db.floatingText = (arg == "on")
        Say("Floating text " .. arg)
    elseif cmd == "scale" and tonumber(arg) then
        db.scale = math.max(0.5, math.min(3, tonumber(arg)))
        Say("Scale: " .. db.scale)
    elseif cmd == "npc" and (arg == "on" or arg == "off") then
        db.npcs = (arg == "on")
        Say("NPC targets " .. (db.npcs and "tracked" or "ignored"))
    elseif cmd == "sameside" and (arg == "on" or arg == "off") then
        db.sameSide = (arg == "on")
        Say("Same faction or race players " .. (db.sameSide and "tracked" or "ignored"))
    elseif cmd == "bg" and (arg == "on" or arg == "off") then
        db.inBattleground = (arg == "on")
        Say("Battlegrounds: addon " .. (db.inBattleground and "active" or "disabled"))
    elseif cmd == "log" and (arg == "on" or arg == "off" or arg == "clear") then
        if arg == "clear" then db.logLines = {} else db.log = (arg == "on") end
        Say("Log " .. arg .. ". Entries are written to disk on /reload or logout.")
    elseif cmd == "mark" then
        local state, number, sub
        if UnitExists("target") then state, number, sub = TR.Measure("target") end
        Log("MARK user reports the text is wrong now: " .. tostring(state) .. " " .. tostring(number) .. " " ..
            tostring(sub) .. " | " .. (UnitExists("target") and ProbeDump("target") or "no target"))
        Say("Marked in the log. Use /reload later to write it to disk.")
    elseif cmd == "unlock" then
        db.locked = false
        db.anchor = "screen"
        badges.screen:EnableMouse(true)
        Say("Screen badge unlocked. Drag it, then type /tr lock. Use /tr test to see it.")
    elseif cmd == "lock" then
        db.locked = true
        badges.screen:EnableMouse(false)
        Say("Locked.")
    elseif cmd == "test" then
        testStep, testNext = 0, 0
        Say("Test sequence running.")
    elseif cmd == "debug" then
        Debug()
    elseif cmd == "reset" then
        for k, v in pairs(DEFAULTS) do db[k] = v end
        PlaceScreenBadge()
        Say("Settings reset.")
    else
        Say("/tr on|off | anchor target|nameplate|both|screen | text on|off | mark | log on|off|clear | npc on|off | sameside on|off | bg on|off | scale N | unlock | lock | test | debug | reset")
    end
end
