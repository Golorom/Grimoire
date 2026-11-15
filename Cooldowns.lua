local _, WTF = ...

-- Grimoire: cooldown alerts, after Dyre's Buff Reminders' cooldown chimes. A
-- line and a sound just before a chosen spell is ready again, also in combat.
-- The client hides cooldowns from addon code in combat and has no event when
-- one ends, but your own casts stay readable, so each cooldown is timed from
-- your cast: the length last read for that spell out of combat (saved), else
-- Classic's. Spells match by name, so every rank counts (the game's Cooldown
-- Manager treats each rank as its own spell on Forever).

local SPELLS = {
    {key = "deathcoil", spell = 6789, label = "Death Coil", cooldown = 120, on = true},
    {key = "howl", spell = 5484, label = "Howl of Terror", cooldown = 40, on = true},
    {key = "shadowward", spell = 6229, label = "Shadow Ward", cooldown = 30, on = true},
    {key = "soulstone", spell = 20707, label = "Soulstone", cooldown = 1800, on = true},
    {key = "feldomination", spell = 18708, label = "Fel Domination", cooldown = 900, on = true},
    {key = "shadowburn", spell = 17877, label = "Shadowburn", cooldown = 15, on = false},
    {key = "conflagrate", spell = 17962, label = "Conflagrate", cooldown = 10, on = false},
    {key = "amplifycurse", spell = 18288, label = "Amplify Curse", cooldown = 180, on = false},
    {key = "inferno", spell = 1122, label = "Inferno", cooldown = 3600, on = false},
}
WTF.COOLDOWN_SPELLS = SPELLS
-- Seconds before the end that the alert comes, so you can act at once.
local LEAD = 0.5
local READ_DELAY = 0.1
local GLOBAL_COOLDOWN = 1.5
local LEARNED_MAX = 3600
local SOUND = {kit = "UI_ORDERHALL_TALENT_READY_TOAST", id = 73281}

local cooldowns = {byName = {}, generation = {}, readyAt = {}}

function WTF.SanitizeCooldowns(saved)
    saved = type(saved) == "table" and saved or {}
    local spells = type(saved.spells) == "table" and saved.spells or {}
    local learned = type(saved.learned) == "table" and saved.learned or {}
    local clean = {enabled = saved.enabled ~= false, sound = saved.sound ~= false, spells = {}, learned = {}}
    for _, def in ipairs(SPELLS) do
        if type(spells[def.key]) == "boolean" then
            clean.spells[def.key] = spells[def.key]
        else
            clean.spells[def.key] = def.on
        end
        local length = learned[def.key]
        if type(length) == "number" and length > GLOBAL_COOLDOWN and length <= LEARNED_MAX then
            clean.learned[def.key] = length
        end
    end
    return clean
end

local function IndexNames()
    cooldowns.byName = {}
    for _, def in ipairs(SPELLS) do
        local name = C_Spell.GetSpellName(def.spell)
        if name then
            cooldowns.byName[name] = def
        end
    end
end

local function Schedule(def, readyAt)
    cooldowns.generation[def.key] = (cooldowns.generation[def.key] or 0) + 1
    local generation = cooldowns.generation[def.key]
    cooldowns.readyAt[def.key] = readyAt
    C_Timer.After(math.max(0, readyAt - GetTime() - LEAD), function()
        if generation ~= cooldowns.generation[def.key] then
            return
        end
        cooldowns.readyAt[def.key] = nil
        local settings = WTF.db.cooldowns
        if settings.enabled and settings.spells[def.key] then
            WTF.Alert("cooldown:" .. def.key, def.label .. " ready.", "info",
                {throttle = 1, sound = settings.sound and SOUND or nil})
        end
    end)
end

-- Out of combat, right after the cast, the real time left (talents included).
local function ReadReal(def, spellID)
    if InCombatLockdown() or type(C_Spell.GetSpellCooldown) ~= "function" then
        return
    end
    local info = C_Spell.GetSpellCooldown(spellID)
    if type(info) ~= "table" then
        return
    end
    local start, duration = info.startTime, info.duration
    if WTF.IsSecret(start) or WTF.IsSecret(duration) or type(start) ~= "number" or type(duration) ~= "number"
            or duration <= GLOBAL_COOLDOWN or duration > LEARNED_MAX then
        return
    end
    WTF.db.cooldowns.learned[def.key] = duration
    Schedule(def, start + duration)
end

local function OnCast(spellID)
    if WTF.IsSecret(spellID) or type(spellID) ~= "number" then
        return
    end
    local name = C_Spell.GetSpellName(spellID)
    local def = name and cooldowns.byName[name]
    if not def then
        return
    end
    local length = WTF.db.cooldowns.learned[def.key] or def.cooldown
    Schedule(def, GetTime() + length)
    C_Timer.After(READ_DELAY, function() ReadReal(def, spellID) end)
end

function WTF.ReportCooldownsDebug()
    WTF.Report("debug_cooldowns enabled=" .. tostring(WTF.db.cooldowns.enabled))
    for _, def in ipairs(SPELLS) do
        local readyAt = cooldowns.readyAt[def.key]
        WTF.Report(string.format("debug_cooldowns %s on=%s length=%s%s", def.key,
            tostring(WTF.db.cooldowns.spells[def.key]),
            tostring(WTF.db.cooldowns.learned[def.key] or def.cooldown),
            readyAt and string.format(" readyIn=%.0f", readyAt - GetTime()) or ""))
    end
end

function WTF.InitializeCooldowns()
    IndexNames()
    local events = CreateFrame("Frame")
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "SPELLS_CHANGED" then
            IndexNames()
        else
            OnCast(spellID)
        end
    end)
end
