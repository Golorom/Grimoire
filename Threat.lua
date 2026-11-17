local _, WTF = ...

-- Grimoire: threat warning (DPS view), cut down from Dyre's Toolkit 2.9.2's
-- Threat.lua. UnitThreatSituation stays readable on Forever in combat (the
-- Toolkit's finding, confirmed by Grimoire's diagnostics in the open world,
-- 2026-11-16; the threat percent read there too, and is not used yet):
--   0  no aggro, less threat than the one holding the mob
--   1  no aggro, but more threat than the one holding it: about to pull
--   2  aggro, but not the most threat
--   3  aggro and the most threat
-- A warning needs someone else to have held the mob first (your Voidwalker
-- or a tank: a 0 or 1 seen for it), so a mob you pull yourself, solo, never
-- warns. A secret answer is skipped, never compared.
--   about to pull (0 -> 1)      yellow line, the "at risk" sound; in a group only
--   pulled (0 or 1 -> 2 or 3)   in a group: red line, the "aggro" sound;
--                               alone: a yellow line with no sound (0.2.1:
--                               with a Voidwalker that happens all the time)
-- Mobs are followed by GUID where it reads, else by their nameplate token.
--
-- 0.3.8:
--   by percent   in a group, the "about to pull" line comes when your threat
--                reaches a percent you set of what pulls the mob (the
--                game's scaled percent, readable in combat on Forever).
--                Once per climb: it comes again only after you drop well
--                below, and never after the mob turned to you. Where the
--                percent is hidden, the 0 -> 1 rule above stands.
--   demon lost   your demon held a mob, then lost it to someone else: a
--                yellow line. When the mob turns to you, the aggro line
--                says it instead, so the two never both come.

local UNITS = {"target", "focus"}
local MAX_PLATES = 40
local REPEAT = 4
WTF.THREAT_RISK_MIN, WTF.THREAT_RISK_MAX, WTF.DEFAULT_THREAT_RISK = 50, 100, 80
-- Below the percent by this much, the warning can come again.
local RISK_REARM = 15
local RISK_SOUND = {kit = "IG_QUEST_FAILED", id = 847}
local AGGRO_SOUND = {kit = "RAID_WARNING", id = 8959}

local threat = {mobs = {}, log = {}}

function WTF.SanitizeThreat(saved)
    saved = type(saved) == "table" and saved or {}
    return {
        enabled = saved.enabled ~= false,
        risk = saved.risk ~= false,
        riskAt = WTF.SanitizeWhole(saved.riskAt, WTF.THREAT_RISK_MIN, WTF.THREAT_RISK_MAX, WTF.DEFAULT_THREAT_RISK),
        petLost = saved.petLost ~= false,
    }
end

local function MobKey(unit)
    local guid = UnitGUID(unit)
    if guid and not WTF.IsSecret(guid) then
        return guid
    end
    return "unit:" .. unit
end

local function MobName(unit)
    local name = UnitName(unit)
    if type(name) == "string" and not WTF.IsSecret(name) then
        return name
    end
    return "a mob"
end

local function Grouped()
    return type(IsInGroup) == "function" and IsInGroup() == true
end

local function Log(text)
    table.insert(threat.log, 1, string.format("%.1f %s", GetTime(), text))
    threat.log[9] = nil
end

-- Your threat as a percent of what pulls the mob, or nil where it does not read.
local function Percent(unit)
    if type(UnitDetailedThreatSituation) ~= "function" then
        return nil
    end
    local _, _, scaled = UnitDetailedThreatSituation("player", unit)
    if WTF.IsSecret(scaled) or type(scaled) ~= "number" then
        return nil
    end
    return scaled
end

local function Readable(value)
    return not WTF.IsSecret(value) and type(value) == "number" and value or nil
end

-- 0.3.8: your demon held the mob (3) and lost it, not to you.
local function CheckPet(unit, mob, key, status)
    local settings = WTF.db.threat
    if not settings.petLost or not UnitExists("pet") or UnitIsDead("pet") == true then
        mob.petStatus = nil
        return
    end
    local petStatus = Readable(UnitThreatSituation("pet", unit))
    local was = mob.petStatus
    mob.petStatus = petStatus
    if was == 3 and petStatus and petStatus <= 1 and not (status and status >= 2) and UnitIsDead(unit) ~= true then
        local now = GetTime()
        if not mob.lostAt or now - mob.lostAt > REPEAT then
            mob.lostAt = now
            local name = MobName(unit)
            Log("lost " .. name)
            WTF.Alert("threat:lost:" .. key, "Your demon lost " .. name .. ".", "warn",
                {throttle = REPEAT, sound = Grouped() and RISK_SOUND or nil})
        end
    end
end

local function Check(unit)
    local settings = WTF.db.threat
    if not settings.enabled or type(UnitThreatSituation) ~= "function" or not UnitExists(unit)
            or not UnitCanAttack("player", unit) then
        return
    end
    local status = UnitThreatSituation("player", unit)
    if WTF.IsSecret(status) then
        threat.secret = (threat.secret or 0) + 1
        return
    end
    local key = MobKey(unit)
    local mob = threat.mobs[key]
    if not mob then
        mob = {}
        threat.mobs[key] = mob
    end
    CheckPet(unit, mob, key, type(status) == "number" and status or nil)
    if type(status) ~= "number" then
        return
    end
    -- By percent, in a group: once per climb past the percent you set.
    local percent = status <= 1 and mob.otherHeld and Percent(unit) or nil
    if percent then
        mob.percentRead = true
        if percent < settings.riskAt - RISK_REARM then
            mob.riskSent = nil
        elseif percent >= settings.riskAt and not mob.riskSent and settings.risk and Grouped() then
            mob.riskSent = true
            local name = MobName(unit)
            Log("risk " .. name .. " " .. math.floor(percent) .. "%")
            WTF.Alert("threat:risk:" .. key, "Careful: " .. math.floor(percent) .. "% threat on " .. name .. ".", "warn",
                {throttle = REPEAT, sound = RISK_SOUND})
        end
    end
    local before = mob.status
    mob.status = status
    if status <= 1 then
        -- You are on its threat list (else the answer is nil) and someone
        -- else holds it.
        mob.otherHeld = true
    end
    if not mob.otherHeld or before == status then
        return
    end
    if status == 0 and not mob.percentRead then
        mob.riskSent = nil
    end
    local name = MobName(unit)
    local now = GetTime()
    local grouped = Grouped()
    if status >= 2 and (before == nil or before <= 1) then
        -- It turned to you: no "about to pull" line for it after this.
        mob.riskSent = true
        if not mob.aggroAt or now - mob.aggroAt > REPEAT then
            mob.aggroAt = now
            Log("aggro " .. name)
            WTF.Alert("threat:aggro:" .. key, "Aggro! " .. name .. " is on you.", grouped and "danger" or "warn",
                {throttle = REPEAT, sound = grouped and AGGRO_SOUND or nil})
        end
    elseif status == 1 and before == 0 and settings.risk and grouped and not mob.percentRead and not mob.riskSent then
        if not mob.riskAt or now - mob.riskAt > REPEAT then
            mob.riskAt = now
            mob.riskSent = true
            Log("risk " .. name)
            WTF.Alert("threat:risk:" .. key, "Careful: about to pull " .. name .. ".", "warn",
                {throttle = REPEAT, sound = RISK_SOUND})
        end
    end
end

local function CheckAll()
    for _, unit in ipairs(UNITS) do
        Check(unit)
    end
    for index = 1, MAX_PLATES do
        local unit = "nameplate" .. index
        if UnitExists(unit) then
            Check(unit)
        end
    end
end

function WTF.ReportThreatDebug()
    WTF.Report(string.format("debug_threat enabled=%s secretAnswers=%d", tostring(WTF.db.threat.enabled),
        threat.secret or 0))
    for _, unit in ipairs({"target", "focus"}) do
        if UnitExists(unit) and type(UnitThreatSituation) == "function" then
            local status = UnitThreatSituation("player", unit)
            WTF.Report("debug_threat " .. unit .. " status=" .. WTF.Describe(status))
        end
    end
    for _, line in ipairs(threat.log) do
        WTF.Report("debug_threat " .. line)
    end
end

function WTF.InitializeThreat()
    local events = CreateFrame("Frame")
    events:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    events:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_ENABLED" then
            threat.mobs = {}
            WTF.ForgetAlerts("threat:")
        elseif event == "PLAYER_TARGET_CHANGED" then
            Check("target")
        elseif type(unit) == "string" and unit ~= "player" and unit ~= "pet" then
            Check(unit)
        else
            CheckAll()
        end
    end)
end
