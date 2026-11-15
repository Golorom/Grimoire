local _, WTF = ...

-- Grimoire: pet warnings.
--   died      your demon disappears in combat: a red line and a sound. Not
--             for Sacrifice (the Voidwalker's own cast), a new summon, or a
--             dismiss. An enslaved demon that leaves says Enslave Demon broke.
--   low       your demon drops to the low-health share in combat: one yellow
--             line, armed again above REARM. Only where the client lets addon
--             code read pet health in combat (a secret answer is skipped);
--             /grim debug_restrictions tells.
-- Pet appearance (UNIT_PET) and your own casts stay readable in combat.

local SACRIFICE = 7812
local ENSLAVE = 1098
-- Summon Imp, Voidwalker, Succubus, Felhunter, and Dismiss Pet: matched by
-- name, so every rank and the client's own IDs count.
local LEAVES = {688, 697, 712, 691, 2641}
local SUMMON_GRACE = 3
local REARM_SHARE = 0.6
local DIED_SOUND = {kit = "IG_QUEST_FAILED", id = 847}

local pet = {}

WTF.PET_LOW_MIN, WTF.PET_LOW_MAX, WTF.DEFAULT_PET_LOW = 10, 60, 35

function WTF.SanitizePet(saved)
    saved = type(saved) == "table" and saved or {}
    return {
        died = saved.died ~= false,
        low = saved.low ~= false,
        lowShare = WTF.SanitizeWhole(saved.lowShare, WTF.PET_LOW_MIN, WTF.PET_LOW_MAX, WTF.DEFAULT_PET_LOW),
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
        pet.lowWarned = false
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

local function OnPetHealth()
    local settings = WTF.db.pet
    if not settings.low or not InCombatLockdown() or not UnitExists("pet") then
        return
    end
    local health, maxHealth = UnitHealth("pet"), UnitHealthMax("pet")
    if WTF.IsSecret(health) or WTF.IsSecret(maxHealth) then
        pet.secretHealth = true
        return
    end
    if type(health) ~= "number" or type(maxHealth) ~= "number" or maxHealth <= 0 or health <= 0 then
        return
    end
    local share = health / maxHealth
    if share >= REARM_SHARE then
        pet.lowWarned = false
    elseif not pet.lowWarned and share * 100 <= settings.lowShare then
        pet.lowWarned = true
        WTF.Alert("pet:low", string.format("Demon low: %d%% health.", math.floor(share * 100)), "warn",
            {throttle = 5})
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
    for _, id in ipairs(LEAVES) do
        if name == SpellName(id) then
            pet.summonAt = GetTime()
            pet.enslaved = false
            return
        end
    end
end

function WTF.ReportPetDebug()
    WTF.Report(string.format("debug_pet exists=%s enslaved=%s secretHealth=%s died=%s low=%s",
        tostring(UnitExists("pet")), tostring(pet.enslaved), tostring(pet.secretHealth),
        tostring(WTF.db.pet.died), tostring(WTF.db.pet.low)))
end

function WTF.InitializePet()
    pet.had = UnitExists("pet")
    local events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_PET", "player")
    events:RegisterUnitEvent("UNIT_HEALTH", "pet")
    -- Your casts and your demon's (Sacrifice); other units' are ignored.
    events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    events:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if event == "UNIT_PET" then
            OnPetChanged()
        elseif event == "UNIT_HEALTH" then
            OnPetHealth()
        elseif unit == "player" or unit == "pet" then
            OnCast(unit, spellID)
        end
    end)
end
