local _, WTF = ...

-- /wtf debug_restrictions reports which combat data this client hides from
-- AddOns. Run it out of combat, then in combat with a target that has your
-- DoTs on it. It reads and prints only; it never changes anything. It never
-- registers for the combat log: the client restricts it and reports the
-- attempt as a blocked action.
local MAX_AURAS = 40
-- Nameplate unit tokens run nameplate1 to nameplate40; the plate frames on
-- the target client do not carry their token.
local MAX_NAMEPLATE_UNITS = 40
local MAX_NAMEPLATES_SHOWN = 3
local MY_DEBUFFS = "HARMFUL|PLAYER"
local RESTRICTION_STATES = {[0] = "inactive", [1] = "activating", [2] = "active"}

local function Report(text)
    WTF.Report("debug_restrictions " .. text)
end

-- Each check runs on its own, so one refused API cannot hide the others.
-- The client may not show Lua errors, so a failure is printed in chat.
local function Step(label, check, ...)
    local ok, failure = pcall(check, ...)
    if not ok then
        Report(label .. " failed: " .. tostring(failure))
    end
end

-- The player's own recent casts, to learn whether spell IDs and cast targets
-- stay readable in combat. Values are kept only as already-safe text.
local casts = {}

-- Grimoire 0.2: what the chat combat log tab gets, for /grim debug_checks:
-- whether its lines reach addon code as text, or arrive secret.
local logText = {seen = 0, secret = 0}

local function WatchCombatLogText()
    local frame = rawget(_G, "COMBATLOG") or rawget(_G, "ChatFrame2")
    if type(frame) ~= "table" or type(frame.AddMessage) ~= "function" or type(hooksecurefunc) ~= "function" then
        logText.missing = true
        return
    end
    hooksecurefunc(frame, "AddMessage", function(_, text)
        logText.seen = logText.seen + 1
        logText.inCombat = InCombatLockdown()
        if WTF.IsSecret(text) then
            logText.secret = logText.secret + 1
            logText.last = "secret"
        elseif type(text) == "string" then
            logText.last = text:sub(1, 60)
        end
    end)
end

-- Core starts this past the class gate, so a non-Warlock registers nothing.
function WTF.InitializeProbe()
    WatchCombatLogText()
    local castFrame = CreateFrame("Frame")
    castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    castFrame:SetScript("OnEvent", function(_, event, _, first, second, third)
        if event == "UNIT_SPELLCAST_SENT" then
            casts.sent = {time = GetTime(), target = WTF.Describe(first), spell = WTF.Describe(third)}
        else
            casts.succeeded = {time = GetTime(), spell = WTF.Describe(second)}
            casts.succeededID = not WTF.IsSecret(second) and type(second) == "number" and second or nil
        end
    end)
end

local function ReportRestrictionStates()
    if type(C_RestrictedActions) ~= "table" or type(C_RestrictedActions.GetAddOnRestrictionState) ~= "function"
        or type(Enum) ~= "table" or type(Enum.AddOnRestrictionType) ~= "table" then
        Report("restriction API missing")
        return
    end
    local types = {}
    for name, value in pairs(Enum.AddOnRestrictionType) do
        types[#types + 1] = {name = name, value = value}
    end
    table.sort(types, function(a, b) return a.value < b.value end)
    local parts = {}
    for _, restriction in ipairs(types) do
        local stateValue = C_RestrictedActions.GetAddOnRestrictionState(restriction.value)
        local stateName = WTF.IsSecret(stateValue) and "secret"
            or RESTRICTION_STATES[stateValue] or tostring(stateValue)
        parts[#parts + 1] = restriction.name .. "=" .. stateName
    end
    Report("states " .. table.concat(parts, " "))
end

local function ReportCombatLog()
    local restricted = "n/a"
    if type(C_CombatLog) == "table" and type(C_CombatLog.IsCombatLogRestricted) == "function" then
        restricted = WTF.Describe(C_CombatLog.IsCombatLogRestricted())
    end
    Report("combatLog restricted=" .. restricted)
end

local function ReportCasts()
    local now = GetTime()
    local sent, succeeded = casts.sent, casts.succeeded
    Report(string.format("lastCast sent=%s target=%s spell=%s; succeeded=%s spell=%s",
        sent and string.format("%.1fs ago", now - sent.time) or "none", sent and sent.target or "-",
        sent and sent.spell or "-",
        succeeded and string.format("%.1fs ago", now - succeeded.time) or "none",
        succeeded and succeeded.spell or "-"))
end

local function DescribeAura(aura)
    if WTF.IsSecret(aura) then
        return "whole table secret"
    end
    if type(aura) ~= "table" then
        return "no data (" .. type(aura) .. ")"
    end
    return string.format("name=%s spellId=%s icon=%s duration=%s expires=%s stacks=%s",
        WTF.Describe(aura.name), WTF.Describe(aura.spellId), WTF.Describe(aura.icon),
        WTF.Describe(aura.duration), WTF.Describe(aura.expirationTime), WTF.Describe(aura.applications))
end

local function HasAuraFunction(name)
    return type(C_UnitAuras) == "table" and type(C_UnitAuras[name]) == "function"
end

local function ReportByIndex(unit)
    if not HasAuraFunction("GetAuraDataByIndex") then
        Report(unit .. " byIndex: missing")
        return
    end
    for index = 1, MAX_AURAS do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, MY_DEBUFFS)
        if not WTF.IsSecret(aura) and type(aura) ~= "table" then
            if index == 1 then
                Report(unit .. " byIndex: none of yours")
            end
            return
        end
        Report(string.format("%s byIndex %d: %s", unit, index, DescribeAura(aura)))
    end
end

-- A duration object can drive Blizzard's timer widgets even when its values
-- are secret; report whether it exists and whether its values are readable.
local function DescribeDuration(unit, instanceID)
    if not HasAuraFunction("GetAuraDuration") then
        return "missing"
    end
    local duration = C_UnitAuras.GetAuraDuration(unit, instanceID)
    if WTF.IsSecret(duration) then
        return "secret object"
    end
    if duration == nil then
        return "none"
    end
    local secretValues = type(duration.HasSecretValues) == "function" and duration:HasSecretValues()
    local remaining = type(duration.GetRemainingDuration) == "function" and duration:GetRemainingDuration()
    return string.format("object secretValues=%s remaining=%s", tostring(secretValues), WTF.Describe(remaining))
end

local function ReportInstances(unit)
    if not HasAuraFunction("GetUnitAuraInstanceIDs") then
        Report(unit .. " instanceIDs: missing")
        return
    end
    local ids = C_UnitAuras.GetUnitAuraInstanceIDs(unit, MY_DEBUFFS)
    if WTF.IsSecret(ids) then
        Report(unit .. " instanceIDs: whole table secret")
        return
    end
    Report(string.format("%s instanceIDs count=%d", unit, #ids))
    for index = 1, math.min(#ids, MAX_AURAS) do
        local id = ids[index]
        local aura = HasAuraFunction("GetAuraDataByAuraInstanceID")
            and C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
        Report(string.format("%s instance %s: %s; duration %s", unit, WTF.Describe(id),
            DescribeAura(aura), DescribeDuration(unit, id)))
    end
end

local function ReportUnitAuras(unit)
    if not HasAuraFunction("GetUnitAuras") then
        Report(unit .. " getUnitAuras: missing")
        return
    end
    local auras = C_UnitAuras.GetUnitAuras(unit, MY_DEBUFFS)
    if WTF.IsSecret(auras) then
        Report(unit .. " getUnitAuras: whole table secret")
        return
    end
    Report(string.format("%s getUnitAuras count=%d", unit, #auras))
    if #auras > 0 then
        Report(unit .. " getUnitAuras 1: " .. DescribeAura(auras[1]))
    end
end

-- Lookups by spell name or ID carry RequiresNonSecretAura instead of
-- RequiresUnitAuraAccess, so they may answer in combat where index access
-- refuses. Spell IDs are Classic's (confirmed for Corruption in client); Bane
-- IDs are unknown, so Banes are looked up by name.
local NAMED_SPELL_IDS = {172, 348, 18265, 980, 603, 702, 704, 1490, 17862, 1714, 5782}
local BANE_NAMES = {"Bane of Agony", "Bane of Doom", "Bane of Havoc"}

local function ReportByName(unit)
    if not HasAuraFunction("GetAuraDataBySpellName") then
        Report(unit .. " byName: missing")
        return
    end
    local names, seen = {}, {}
    for _, id in ipairs(NAMED_SPELL_IDS) do
        local name = C_Spell.GetSpellName(id)
        if name and not seen[name] then
            names[#names + 1], seen[name] = name, true
        end
    end
    for _, name in ipairs(BANE_NAMES) do
        if not seen[name] then
            names[#names + 1], seen[name] = name, true
        end
    end
    local found = 0
    for _, name in ipairs(names) do
        local aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, MY_DEBUFFS)
        if WTF.IsSecret(aura) or aura ~= nil then
            found = found + 1
            Report(string.format("%s byName %s: %s", unit, name, DescribeAura(aura)))
        end
    end
    Report(string.format("%s byName checked=%d found=%d", unit, #names, found))
end

local function ReportBySpellID(unit)
    local spellID = casts.succeededID
    if not HasAuraFunction("GetUnitAuraBySpellID") or not spellID then
        Report(unit .. " bySpellID: " .. (spellID and "missing" or "no readable last cast"))
        return
    end
    Report(string.format("%s bySpellID %d: %s", unit, spellID,
        DescribeAura(C_UnitAuras.GetUnitAuraBySpellID(unit, spellID))))
end

local function ReportUnit(unit)
    if not UnitExists(unit) then
        Report(unit .. " none")
        return
    end
    Report(string.format("%s name=%s guid=%s canAttack=%s", unit, WTF.Describe(UnitName(unit)),
        WTF.Describe(UnitGUID(unit)), WTF.Describe(UnitCanAttack("player", unit))))
    Step(unit .. " byIndex", ReportByIndex, unit)
    Step(unit .. " instanceIDs", ReportInstances, unit)
    Step(unit .. " getUnitAuras", ReportUnitAuras, unit)
    Step(unit .. " byName", ReportByName, unit)
    Step(unit .. " bySpellID", ReportBySpellID, unit)
end

local function ReportNameplates()
    if type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlates) ~= "function" then
        Report("nameplates: C_NamePlate.GetNamePlates missing")
        return
    end
    local units = {}
    for index = 1, MAX_NAMEPLATE_UNITS do
        local unit = "nameplate" .. index
        if UnitExists(unit) then
            units[#units + 1] = unit
        end
    end
    Report(string.format("nameplates frames=%d units=%d", #C_NamePlate.GetNamePlates(), #units))
    for index = 1, math.min(#units, MAX_NAMEPLATES_SHOWN) do
        Step(units[index], ReportUnit, units[index])
    end
end

local function ReportTargetIsFocus()
    if UnitExists("target") and UnitExists("focus") then
        Report("targetIsFocus=" .. WTF.Describe(UnitIsUnit("target", "focus")))
    end
end

-- /grim debug_checks (Grimoire 0.2): short answers to what the coming
-- features need, out of combat and in combat. Reads and prints only.
local SHADOW_BOLT = 686

function WTF.ReportForeverChecks()
    local function Line(text)
        WTF.Report("debug_checks " .. text)
    end
    local function Try(label, check)
        local ok, failure = pcall(check)
        if not ok then
            Line(label .. " failed: " .. tostring(failure))
        end
    end
    Line("combat=" .. tostring(InCombatLockdown()))
    Try("threat", function()
        for _, unit in ipairs({"target", "nameplate1", "nameplate2"}) do
            if UnitExists(unit) then
                local status = type(UnitThreatSituation) == "function" and UnitThreatSituation("player", unit)
                local tanking, detail, scaled = nil, nil, nil
                if type(UnitDetailedThreatSituation) == "function" then
                    tanking, detail, scaled = UnitDetailedThreatSituation("player", unit)
                end
                Line(string.format("threat %s status=%s detailedStatus=%s tanking=%s percent=%s", unit,
                    WTF.Describe(status), WTF.Describe(detail), WTF.Describe(tanking), WTF.Describe(scaled)))
            end
        end
    end)
    Try("cooldown", function()
        local id = casts.succeededID
        if id and type(C_Spell.GetSpellCooldown) == "function" then
            local info = C_Spell.GetSpellCooldown(id)
            Line(string.format("cooldown spell=%s start=%s duration=%s", tostring(id),
                WTF.Describe(info and info.startTime), WTF.Describe(info and info.duration)))
        else
            Line("cooldown: cast a spell first")
        end
    end)
    Try("pet", function()
        if UnitExists("pet") then
            Line(string.format("pet health=%s max=%s dead=%s", WTF.Describe(UnitHealth("pet")),
                WTF.Describe(UnitHealthMax("pet")), WTF.Describe(UnitIsDead("pet"))))
        else
            Line("pet none")
        end
    end)
    Try("nightfall", function()
        -- With Nightfall up, Shadow Bolt is instant: if its cast time reads in
        -- combat, Grimoire could print a line for the proc too.
        local info = type(C_Spell.GetSpellInfo) == "function" and C_Spell.GetSpellInfo(SHADOW_BOLT)
        Line("shadowBoltCastTime=" .. WTF.Describe(type(info) == "table" and info.castTime or nil))
    end)
    Line(string.format("combatLogText seen=%d secret=%d missing=%s lastInCombat=%s last=%s", logText.seen,
        logText.secret, tostring(logText.missing == true), tostring(logText.inCombat), tostring(logText.last)))
    Line(string.format("auraSoundAPI=%s", tostring(type(C_UnitAuras) == "table"
        and type(C_UnitAuras.AddAuraSound) == "function")))
end

function WTF.ReportRestrictions()
    Report(string.format("combat=%s secretAPI=%s", tostring(InCombatLockdown()),
        tostring(type(issecretvalue) == "function")))
    Step("states", ReportRestrictionStates)
    Step("combatLog", ReportCombatLog)
    Step("lastCast", ReportCasts)
    Step("target", ReportUnit, "target")
    Step("focus", ReportUnit, "focus")
    Step("targetIsFocus", ReportTargetIsFocus)
    Step("nameplates", ReportNameplates)
end

-- Grimoire 0.2.1: background diagnostics. While you play, Grimoire notes
-- whether the values its coming features need come back readable, secret,
-- or empty: threat, spell cooldowns, pet health, Shadow Bolt's cast time,
-- the combat log tab's text, and which AddOn restrictions are active. It
-- samples a few times per fight (every COMBAT_INTERVAL seconds, at most
-- COMBAT_SAMPLES times), once after each fight and once after login, and
-- reads a spell's cooldown just after you cast it (at most every CAST_GAP
-- seconds). Only counts are kept, by check and by place (in or out of
-- combat, open world or instance), with one short readable sample: never a
-- name or a GUID. They live in GrimoireAccountDB.diagnostics, which the game
-- writes when you log out or /reload. It reads only what /grim debug_checks
-- reads, and never an aura (an aura read in combat raises a client warning).
-- A check that fails three times stops for the session. Nothing is sent.
local RECORD_VERSION = 1
local MAX_FACTS = 150
local SAMPLE_LIMIT = 40
local COMBAT_INTERVAL = 3
local COMBAT_SAMPLES = 10
local FIRST_COMBAT_SAMPLE = 1
local AFTER_COMBAT = 2
local AFTER_LOGIN = 10
local CAST_GAP = 2
local CAST_READ_DELAY = 0.2
local MAX_FAILURES = 3
local COUNT_FIELDS = {"n", "readable", "secret", "none", "error"}

-- The questions the 0.2 test asked, answered from the combat counts.
local ANSWERS = {
    {label = "Threat state in combat", check = "threat.target"},
    {label = "Spell cooldowns in combat", check = "cooldown.read"},
    {label = "Pet health in combat", check = "pet.health"},
    {label = "Shadow Bolt cast time in combat", check = "shadowbolt.castTime"},
}

local recorder = {generation = 0, castAt = nil, failures = {}, stopped = {}, factCount = 0,
    logSeen = 0, logSecret = 0}

local function Count(value)
    if type(value) ~= "number" or value < 0 or value ~= math.floor(value) then
        return 0
    end
    return value
end

local function Text(value)
    return type(value) == "string" and value:sub(1, SAMPLE_LIMIT) or nil
end

-- A damaged or older record starts over; a sane one keeps at most MAX_FACTS.
function WTF.SanitizeDiagnosticsRecord(saved)
    if type(saved) ~= "table" or saved.version ~= RECORD_VERSION then
        return {version = RECORD_VERSION, sessions = 0, facts = {}}
    end
    local facts, count = {}, 0
    if type(saved.facts) == "table" then
        for key, fact in pairs(saved.facts) do
            if type(key) == "string" and type(fact) == "table" and count < MAX_FACTS then
                local clean = {sample = Text(fact.sample), first = Text(fact.first), last = Text(fact.last)}
                for _, field in ipairs(COUNT_FIELDS) do
                    clean[field] = Count(fact[field])
                end
                facts[key], count = clean, count + 1
            end
        end
    end
    return {version = RECORD_VERSION, sessions = Count(saved.sessions), since = Text(saved.since),
        build = Text(saved.build), facts = facts}
end

-- The per-character switch, on by default.
function WTF.SanitizeDiagnostics(saved)
    saved = type(saved) == "table" and saved or {}
    return {enabled = saved.enabled ~= false}
end

local function Record()
    return WTF.accountDB and WTF.accountDB.diagnostics
end

local function Enabled()
    return WTF.db and WTF.db.diagnostics and WTF.db.diagnostics.enabled == true and Record() ~= nil
end

local function Stamp()
    if type(date) ~= "function" then
        return nil
    end
    local ok, text = pcall(date, "%Y-%m-%d %H:%M")
    return ok and Text(text) or nil
end

local function Place()
    local where = "world"
    if type(IsInInstance) == "function" then
        local inside = IsInInstance()
        if WTF.IsSecret(inside) then
            where = "unknown"
        elseif inside == true or inside == 1 then
            where = "instance"
        end
    end
    return (InCombatLockdown() and "combat" or "idle") .. "." .. where
end

local function Kind(value)
    if WTF.IsSecret(value) then
        return "secret"
    end
    return value == nil and "none" or "readable"
end

-- sample: plain text or a number, only for a readable value or an error.
local function Add(check, kind, sample, amount)
    if not Enabled() then
        return
    end
    local record = Record()
    local key = check .. "@" .. Place()
    local fact = record.facts[key]
    if not fact then
        if recorder.factCount >= MAX_FACTS then
            return
        end
        fact = {n = 0, readable = 0, secret = 0, none = 0, error = 0, first = Stamp()}
        record.facts[key] = fact
        recorder.factCount = recorder.factCount + 1
    end
    amount = amount or 1
    fact.n = fact.n + amount
    fact[kind] = fact[kind] + amount
    if (kind == "readable" or kind == "error") and (type(sample) == "string" or type(sample) == "number"
        or type(sample) == "boolean") then
        fact.sample = Text(tostring(sample))
    end
    fact.last = Stamp()
end

-- A value's kind, with the value itself as the sample when it is readable.
local function Note(check, value)
    local kind = Kind(value)
    Add(check, kind, kind == "readable" and value or nil)
end

local function Try(check, run)
    if recorder.stopped[check] then
        return
    end
    local ok, failure = pcall(run)
    if not ok then
        Add(check, "error", WTF.IsSecret(failure) and "secret error" or tostring(failure))
        recorder.failures[check] = (recorder.failures[check] or 0) + 1
        if recorder.failures[check] >= MAX_FAILURES then
            recorder.stopped[check] = true
        end
    end
end

local function HasSecrets(name)
    return type(C_Secrets) == "table" and type(C_Secrets[name]) == "function"
end

-- Your target, when it is there and attackable; a secret answer is noted
-- once per sample and counts as not attackable.
local function HostileTarget()
    if not UnitExists("target") then
        return false
    end
    local canAttack = UnitCanAttack("player", "target")
    if WTF.IsSecret(canAttack) then
        Add("target.canAttack", "secret")
        return false
    end
    return canAttack == true
end

local function SampleRestrictions()
    Try("restrictions", function()
        local kinds = type(Enum) == "table" and Enum.AddOnRestrictionType
        if type(kinds) ~= "table" or type(C_RestrictedActions) ~= "table"
            or type(C_RestrictedActions.IsAddOnRestrictionActive) ~= "function" then
            return
        end
        for name, value in pairs(kinds) do
            local active = C_RestrictedActions.IsAddOnRestrictionActive(value)
            if WTF.IsSecret(active) then
                Add("restriction." .. tostring(name), "secret")
            elseif active == true then
                Add("restriction." .. tostring(name), "readable", "active")
            end
        end
    end)
end

local function Sample()
    local hostile = false
    Try("target", function() hostile = HostileTarget() end)
    if hostile then
        Try("threat.target", function()
            if type(UnitThreatSituation) == "function" then
                Note("threat.target", UnitThreatSituation("player", "target"))
            end
        end)
        Try("threat.percent", function()
            if type(UnitDetailedThreatSituation) == "function" then
                local _, _, scaled = UnitDetailedThreatSituation("player", "target")
                Note("threat.percent", scaled)
            end
        end)
        Try("threat.pet", function()
            if UnitExists("pet") and type(UnitThreatSituation) == "function" then
                Note("threat.pet", UnitThreatSituation("pet", "target"))
            end
        end)
        Try("threat.hidden", function()
            if HasSecrets("ShouldUnitThreatStateBeSecret") then
                Note("threat.hidden", C_Secrets.ShouldUnitThreatStateBeSecret("player", "target"))
            end
        end)
        -- Only whether it reads: a GUID is never kept.
        Try("target.guid", function() Add("target.guid", Kind(UnitGUID("target"))) end)
    end
    Try("pet.health", function()
        if UnitExists("pet") then
            Note("pet.health", UnitHealth("pet"))
        end
    end)
    Try("shadowbolt.castTime", function()
        if type(C_Spell.GetSpellInfo) ~= "function" then
            return
        end
        local info = C_Spell.GetSpellInfo(SHADOW_BOLT)
        if WTF.IsSecret(info) or type(info) ~= "table" then
            Add("shadowbolt.castTime", Kind(info))
            return
        end
        local castTime = info.castTime
        Note("shadowbolt.castTime", castTime)
        -- Instant: Nightfall was up, and the cast time showed it.
        if not WTF.IsSecret(castTime) and castTime == 0 then
            Add("shadowbolt.instant", "readable", 0)
        end
    end)
    Try("auras.hidden", function()
        if HasSecrets("ShouldAurasBeSecret") then
            Note("auras.hidden", C_Secrets.ShouldAurasBeSecret())
        end
    end)
    -- The combat log tab's lines since the last sample: counts only.
    Try("combatlog.text", function()
        local seen, hidden = logText.seen - recorder.logSeen, logText.secret - recorder.logSecret
        recorder.logSeen, recorder.logSecret = logText.seen, logText.secret
        if hidden > 0 then
            Add("combatlog.text", "secret", nil, hidden)
        end
        if seen - hidden > 0 then
            Add("combatlog.text", "readable", nil, seen - hidden)
        end
    end)
end

local function SampleCooldown(spellID)
    Try("cooldown.read", function()
        if type(C_Spell.GetSpellCooldown) ~= "function" then
            return
        end
        local info = C_Spell.GetSpellCooldown(spellID)
        if WTF.IsSecret(info) or type(info) ~= "table" then
            Add("cooldown.read", Kind(info))
            return
        end
        Note("cooldown.read", info.duration)
    end)
    Try("cooldown.hidden", function()
        if HasSecrets("ShouldSpellCooldownBeSecret") then
            Note("cooldown.hidden", C_Secrets.ShouldSpellCooldownBeSecret(spellID))
        end
    end)
end

local function CombatSample(generation, left)
    if generation ~= recorder.generation or left <= 0 or not InCombatLockdown() or not Enabled() then
        return
    end
    if left == COMBAT_SAMPLES then
        SampleRestrictions()
    end
    Sample()
    C_Timer.After(COMBAT_INTERVAL, function() CombatSample(generation, left - 1) end)
end

local function OnRecorderEvent(_, event, _, _, spellID)
    if not Enabled() then
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        recorder.generation = recorder.generation + 1
        local generation = recorder.generation
        C_Timer.After(FIRST_COMBAT_SAMPLE, function() CombatSample(generation, COMBAT_SAMPLES) end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        recorder.generation = recorder.generation + 1
        local generation = recorder.generation
        C_Timer.After(AFTER_COMBAT, function()
            if generation == recorder.generation and not InCombatLockdown() and Enabled() then
                Sample()
            end
        end)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        Add("cast.spellID", Kind(spellID))
        if WTF.IsSecret(spellID) or type(spellID) ~= "number" then
            return
        end
        local now = GetTime()
        if recorder.castAt and now - recorder.castAt < CAST_GAP then
            return
        end
        recorder.castAt = now
        C_Timer.After(CAST_READ_DELAY, function()
            if Enabled() then
                SampleCooldown(spellID)
            end
        end)
    end
end

-- Core calls this from InitializeProbe's caller at login, past the class gate.
function WTF.StartDiagnostics()
    local record = Record()
    if not record then
        return
    end
    recorder.factCount = 0
    for _ in pairs(record.facts) do
        recorder.factCount = recorder.factCount + 1
    end
    recorder.logSeen, recorder.logSecret = logText.seen, logText.secret
    if Enabled() then
        record.sessions = record.sessions + 1
        record.since = record.since or Stamp()
        if type(GetBuildInfo) == "function" then
            local version, build = GetBuildInfo()
            if type(version) == "string" and type(build) == "string" then
                record.build = Text(version .. " " .. build)
            end
        end
    end
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    frame:SetScript("OnEvent", OnRecorderEvent)
    C_Timer.After(AFTER_LOGIN, function()
        if Enabled() and not InCombatLockdown() then
            Sample()
        end
    end)
end

-- The switch changed: turning it off stops a fight's sampling at once.
function WTF.RefreshDiagnostics()
    recorder.generation = recorder.generation + 1
end

-- Sums one check's counts over the places in combat.
local function CombatTotals(check)
    local totals = {n = 0, readable = 0, secret = 0, none = 0, error = 0}
    local record = Record()
    for key, fact in pairs(record and record.facts or {}) do
        if key:sub(1, #check + 8) == check .. "@combat." then
            for _, field in ipairs(COUNT_FIELDS) do
                totals[field] = totals[field] + fact[field]
            end
        end
    end
    return totals
end

local function Verdict(check)
    local totals = CombatTotals(check)
    if totals.readable + totals.secret == 0 then
        return totals.n == 0 and "not seen yet" or string.format("no answer yet (%d empty, %d failed)",
            totals.none, totals.error)
    end
    local word = totals.secret == 0 and "readable" or totals.readable == 0 and "secret" or "mixed"
    return string.format("%s (%d readable, %d secret)", word, totals.readable, totals.secret)
end

function WTF.ReportDiagnostics()
    local function Line(text)
        WTF.Report("debug_log " .. text)
    end
    local record = Record()
    if not record then
        Line("no record")
        return
    end
    Line(string.format("%s; since %s, %d sessions, client %s", Enabled() and "recording" or "off",
        tostring(record.since or "-"), record.sessions, tostring(record.build or "-")))
    for _, answer in ipairs(ANSWERS) do
        Line(answer.label .. ": " .. Verdict(answer.check))
    end
    local keys = {}
    for key in pairs(record.facts) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local fact = record.facts[key]
        Line(string.format("%s n=%d readable=%d secret=%d none=%d error=%d sample=%s last=%s", key, fact.n,
            fact.readable, fact.secret, fact.none, fact.error, tostring(fact.sample or "-"),
            tostring(fact.last or "-")))
    end
end

function WTF.ResetDiagnostics()
    local record = Record()
    if not record then
        return
    end
    record.facts, record.sessions, record.since = {}, 0, Stamp()
    recorder.factCount = 0
    WTF.Report("debug_log cleared. Counting starts again now.")
end
