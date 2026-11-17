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

local UNITS = {"target", "focus"}
local MAX_PLATES = 40
local REPEAT = 4
local RISK_SOUND = {kit = "IG_QUEST_FAILED", id = 847}
local AGGRO_SOUND = {kit = "RAID_WARNING", id = 8959}

local threat = {mobs = {}, log = {}}

function WTF.SanitizeThreat(saved)
    saved = type(saved) == "table" and saved or {}
    return {
        enabled = saved.enabled ~= false,
        risk = saved.risk ~= false,
        sounds = saved.sounds ~= false,
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
    if type(status) ~= "number" then
        return
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
    local name = MobName(unit)
    local now = GetTime()
    local grouped = Grouped()
    if status >= 2 and (before == nil or before <= 1) then
        if not mob.aggroAt or now - mob.aggroAt > REPEAT then
            mob.aggroAt = now
            Log("aggro " .. name)
            WTF.Alert("threat:aggro:" .. key, "Aggro! " .. name .. " is on you.", grouped and "danger" or "warn",
                {throttle = REPEAT, sound = grouped and settings.sounds and AGGRO_SOUND or nil})
        end
    elseif status == 1 and before == 0 and settings.risk and grouped then
        if not mob.riskAt or now - mob.riskAt > REPEAT then
            mob.riskAt = now
            Log("risk " .. name)
            WTF.Alert("threat:risk:" .. key, "Careful: about to pull " .. name .. ".", "warn",
                {throttle = REPEAT, sound = settings.sounds and RISK_SOUND or nil})
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
