local _, WTF = ...

-- Grimoire: pet warnings.
--   died      your demon disappears in combat: a red line and a sound. Not
--             for Sacrifice (the Voidwalker's own cast), a new summon, or a
--             dismiss. An enslaved demon that leaves says Enslave Demon broke.
--   taunt     in a group where you are not the tank, your Voidwalker's
--             Torment or Suffering (the Felguard's Anguish) on autocast pulls
--             mobs off the tank: a yellow line when that becomes true and
--             once more as combat starts (Dyre's Toolkit 2.9.0's PetTaunt.lua,
--             MIT, without its message box and chat line). Checked out of
--             combat; a secret answer gives no warning.
-- No low-health line: on Forever a demon's health is secret to addon code in
-- and out of combat (Grimoire's diagnostics, 2026-11-16), so it could never
-- fire; it was removed in 0.2.1.
-- Pet appearance (UNIT_PET) and your own casts stay readable in combat.

local SACRIFICE = 7812
local ENSLAVE = 1098
-- Summon Imp, Voidwalker, Succubus, Felhunter, and Dismiss Pet: matched by
-- name, so every rank and the client's own IDs count.
local LEAVES = {688, 697, 712, 691, 2641}
-- Forever's Summon Incubus has no Classic ID: by its English name.
local LEAVE_NAMES = {["Summon Incubus"] = true}
local SUMMON_GRACE = 3
-- Torment, Suffering, Anguish: every rank, matched by name.
local PET_TAUNTS = {3716, 7809, 7810, 7811, 11774, 11775, 27270, 17735, 17750, 17751, 17752, 27271,
    33701, 33698, 33699, 33700}
local TAUNT_GAP = 30
local PET_ACTION_SLOTS = rawget(_G, "NUM_PET_ACTION_SLOTS") or 10
local DIED_SOUND = {kit = "IG_QUEST_FAILED", id = 847}

local pet = {}

function WTF.SanitizePet(saved)
    saved = type(saved) == "table" and saved or {}
    return {
        died = saved.died ~= false,
        taunt = saved.taunt ~= false,
    }
end

local function SpellName(id)
    return type(id) == "number" and C_Spell.GetSpellName(id) or nil
end

local function OnPetChanged()
    local exists = UnitExists("pet")
    local had = pet.had
    pet.had = exists
    if exists then
        return
    end
    local now = GetTime()
    local meant = (pet.sacrificeAt and now - pet.sacrificeAt < SUMMON_GRACE)
        or (pet.summonAt and now - pet.summonAt < SUMMON_GRACE)
    if meant then
        return
    end
    local enslaved = pet.enslaved
    pet.enslaved = false
    if not had or not WTF.db.pet.died then
        return
    end
    -- An enslaved demon that leaves turns on you, also out of combat.
    if enslaved then
        WTF.Alert("pet:enslave", "Enslave Demon broke!", "danger", {throttle = 2, sound = DIED_SOUND})
    elseif InCombatLockdown() then
        WTF.Alert("pet:died", "Your demon died.", "danger", {throttle = 5, sound = DIED_SOUND})
    end
end

local function OnCast(unit, spellID)
    if WTF.IsSecret(spellID) then
        return
    end
    local name = SpellName(spellID)
    if unit == "pet" then
        if name and name == SpellName(SACRIFICE) then
            pet.sacrificeAt = GetTime()
        end
        return
    end
    if not name then
        return
    end
    -- A new demon replaces the old one: that one leaving is meant.
    if name == SpellName(ENSLAVE) then
        pet.enslaved = true
        pet.summonAt = GetTime()
        return
    end
    if LEAVE_NAMES[name] then
        pet.summonAt = GetTime()
        pet.enslaved = false
        return
    end
    for _, id in ipairs(LEAVES) do
        if name == SpellName(id) then
            pet.summonAt = GetTime()
            pet.enslaved = false
            return
        end
    end
end

-- Pet taunt ------------------------------------------------------------------

local function Plain(value)
    if WTF.IsSecret(value) then
        return nil
    end
    return value
end

-- Your group's tank: the Tank role, or a raid's main tank. A secret or
-- missing answer is not a tank.
local function DesignatedTank()
    if type(UnitGroupRolesAssigned) == "function" and Plain(UnitGroupRolesAssigned("player")) == "TANK" then
        return true
    end
    return type(IsInRaid) == "function" and IsInRaid() and type(GetPartyAssignment) == "function"
        and Plain(GetPartyAssignment("MAINTANK", "player")) == true
end

-- The names of your demon's taunts that are on autocast.
local function TauntsOn()
    local names, on = {}, {}
    for _, id in ipairs(PET_TAUNTS) do
        local name = Plain(SpellName(id))
        if name then
            names[name] = true
        end
    end
    if type(GetPetActionInfo) ~= "function" or Plain(UnitExists("pet")) ~= true then
        return on
    end
    for slot = 1, PET_ACTION_SLOTS do
        local name, _, isToken, _, _, autoCastEnabled = GetPetActionInfo(slot)
        if not WTF.IsSecret(name) and not WTF.IsSecret(autoCastEnabled) and not isToken and names[name]
                and autoCastEnabled == true then
            on[#on + 1] = name
        end
    end
    return on
end

local function TauntText()
    if not WTF.db.pet.taunt or type(IsInGroup) ~= "function" or not IsInGroup() or DesignatedTank() then
        return nil
    end
    local on = TauntsOn()
    if #on > 0 then
        return "Pet taunt on: " .. table.concat(on, " and ") .. (#on > 1 and " are" or " is")
            .. " on autocast in a group. Turn it off."
    end
end

local function WarnTaunt()
    WTF.Alert("pet:taunt", pet.tauntText, "warn", {throttle = TAUNT_GAP})
end

-- Out of combat: warns when the text appears or changes.
local function CheckTaunt()
    if InCombatLockdown() then
        return
    end
    local text = TauntText()
    local changed = text ~= nil and text ~= pet.tauntText
    pet.tauntText = text
    if changed then
        WarnTaunt()
    end
end

function WTF.ReportPetDebug()
    WTF.Report(string.format("debug_pet exists=%s enslaved=%s died=%s taunt=%s tauntNow=%s",
        tostring(UnitExists("pet")), tostring(pet.enslaved), tostring(WTF.db.pet.died),
        tostring(WTF.db.pet.taunt), tostring(pet.tauntText or "none")))
end

function WTF.RefreshPetTaunt()
    CheckTaunt()
end

function WTF.InitializePet()
    pet.had = UnitExists("pet")
    local events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_PET", "player")
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PET_BAR_UPDATE", "SPELLS_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"}) do
        events:RegisterEvent(event)
    end
    pcall(events.RegisterEvent, events, "PLAYER_ROLES_ASSIGNED")
    -- Your casts and your demon's (Sacrifice); other units' are ignored.
    events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    events:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if event == "UNIT_PET" then
            OnPetChanged()
            CheckTaunt()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if unit == "player" or unit == "pet" then
                OnCast(unit, spellID)
            end
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- Once more as the fight starts.
            if pet.tauntText then
                WarnTaunt()
            end
        else
            CheckTaunt()
        end
    end)
end
