local _, WTF = ...

-- Grimoire: Nightfall (Shadow Trance: your next Shadow Bolt is instant).
-- Addon code cannot read buffs in combat on Forever, so it never learns of
-- the proc itself. Two things the game does for it instead:
--   sound  the game plays a sound the moment the buff lands, also in combat
--          (C_UnitAuras.AddAuraSound, trigger Added; as Dyre's Buff
--          Reminders does). A game sound file by ID: file paths stay silent
--          in client (Dyre's finding). Refused during a boss encounter, so a
--          change then waits until the encounter ends.
--   icon   a small icon the game's aura container draws while the buff is
--          up, with its time left (as the DoT tracker's slots).
-- The buff's real ID is read once out of combat by name and saved, so a
-- Forever ID that differs from Classic's corrects itself.

local BUFF_IDS = {17941}
local BUFF_NAME = "Shadow Trance"
-- The Imp's spell chirp (game file 639156; Dyre's Buff Reminders' default).
local SOUND_FILE = 639156
local THROTTLE = 1
local ICON_SIZE = 40
local DEFAULT_POINT = {"CENTER", "CENTER", 0, -90}
local AURA_FILTER = "HELPFUL"

local procs = {handles = {}, deferred = false}
local holder, container

function WTF.SanitizeProcs(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    local learned = saved.learned
    return {
        sound = saved.sound ~= false,
        icon = saved.icon ~= false,
        position = sanitizePosition(saved.position),
        learned = (type(learned) == "number" and learned > 0 and learned == math.floor(learned)) and learned or nil,
    }
end

local function BuffIDs()
    local ids, seen = {}, {}
    for _, id in ipairs(BUFF_IDS) do
        ids[#ids + 1], seen[id] = id, true
    end
    local learned = WTF.db.procs.learned
    if learned and not seen[learned] then
        ids[#ids + 1] = learned
    end
    return ids
end

local function IDSet()
    local set = {}
    for _, id in ipairs(BuffIDs()) do
        set[id] = true
    end
    return set
end

local function EncounterRestricted()
    local kinds = type(Enum) == "table" and Enum.AddOnRestrictionType
    return type(kinds) == "table" and kinds.Encounter ~= nil and type(C_RestrictedActions) == "table"
        and type(C_RestrictedActions.IsAddOnRestrictionActive) == "function"
        and C_RestrictedActions.IsAddOnRestrictionActive(kinds.Encounter) == true
end

function WTF.ProcSoundsAvailable()
    return type(C_UnitAuras) == "table" and type(C_UnitAuras.AddAuraSound) == "function"
        and type(C_UnitAuras.RemoveAuraSound) == "function"
end

function WTF.ApplyProcSounds()
    if not WTF.ProcSoundsAvailable() then
        return
    end
    if EncounterRestricted() then
        procs.deferred = true
        return
    end
    procs.deferred = false
    for _, handle in ipairs(procs.handles) do
        pcall(C_UnitAuras.RemoveAuraSound, handle)
    end
    procs.handles = {}
    if not WTF.db.procs.sound or not WTF.db.alerts.sounds then
        return
    end
    local trigger = type(Enum) == "table" and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added or 0
    for _, id in ipairs(BuffIDs()) do
        local ok, handle = pcall(C_UnitAuras.AddAuraSound, trigger, {
            spellID = id,
            unitToken = "player",
            outputChannel = "master",
            throttleSeconds = THROTTLE,
            soundFileID = SOUND_FILE,
        })
        if ok and handle then
            procs.handles[#procs.handles + 1] = handle
        end
    end
end

-- Out of combat: the buff's real ID, by name, saved once.
local function LearnID()
    if InCombatLockdown() or type(C_UnitAuras) ~= "table"
            or type(C_UnitAuras.GetAuraDataBySpellName) ~= "function" then
        return
    end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", BUFF_NAME, AURA_FILTER)
    if not ok or type(aura) ~= "table" or WTF.IsSecret(aura.spellId) or type(aura.spellId) ~= "number" then
        return
    end
    if IDSet()[aura.spellId] then
        return
    end
    WTF.db.procs.learned = aura.spellId
    WTF.ApplyProcSounds()
    if container then
        container:SetAuraSlotCandidateFilters("nightfall", {includeSpellIDs = IDSet()})
    end
end

function WTF.RefreshProcs()
    if not holder then
        return
    end
    -- In Edit Mode: a dim sample, so the spot shows while you place it.
    holder.sample:SetShown(not WTF.db.locked)
    holder:SetShown(WTF.db.procs.icon or not WTF.db.locked)
end

function WTF.ResetProcsPosition()
    WTF.db.procs.position = nil
    if holder then
        holder:ClearAllPoints()
        holder:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[2], DEFAULT_POINT[3], DEFAULT_POINT[4])
    end
end

local function CreateIcon()
    holder = CreateFrame("Frame", "GrimoireNightfall", UIParent)
    holder:SetSize(ICON_SIZE, ICON_SIZE)
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    holder:EnableMouse(false)
    WTF.RegisterMovable(holder, function(position) WTF.db.procs.position = position end,
        {name = "Grimoire Nightfall icon", default = WTF.EditModeDefault(DEFAULT_POINT)})
    holder.sample = holder:CreateTexture(nil, "BACKGROUND")
    holder.sample:SetAllPoints()
    holder.sample:SetTexture(C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(BUFF_IDS[1]) or 136223)
    holder.sample:SetAlpha(0.4)
    local position = WTF.db.procs.position
    if position then
        holder:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        holder:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[2], DEFAULT_POINT[3], DEFAULT_POINT[4])
    end
    if not WTF.AuraEngineKind or not WTF.AuraEngineKind() then
        return
    end
    container = WTF.shared.CreateAuraContainer(holder)
    container:SetPoint("TOPLEFT")
    container:SetSize(1, 1)
    container:AddAuraSlot("nightfall", AURA_FILTER, {
        candidateFilters = {includeSpellIDs = IDSet()},
        initializeFrame = function(button)
            button:ClearAllPoints()
            button:SetPoint("CENTER", holder, "CENTER")
            button:SetSize(ICON_SIZE, ICON_SIZE)
            button:SetMouseClickEnabled(false)
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            button:SetIcon(icon)
            local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cooldown:SetAllPoints()
            button:SetDurationCooldown(cooldown)
        end,
    })
    container:SetUnit("player")
end

function WTF.ReportProcsDebug()
    local ids = {}
    for _, id in ipairs(BuffIDs()) do
        ids[#ids + 1] = tostring(id)
    end
    WTF.Report(string.format("debug_procs api=%s sound=%s icon=%s handles=%d deferred=%s ids=%s",
        tostring(WTF.ProcSoundsAvailable()), tostring(WTF.db.procs.sound), tostring(WTF.db.procs.icon),
        #procs.handles, tostring(procs.deferred), table.concat(ids, ",")))
end

function WTF.InitializeProcs()
    CreateIcon()
    WTF.ApplyProcSounds()
    WTF.RefreshProcs()
    local events = CreateFrame("Frame")
    events:RegisterEvent("ENCOUNTER_END")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterUnitEvent("UNIT_AURA", "player")
    events:SetScript("OnEvent", function(_, event)
        if event == "UNIT_AURA" then
            LearnID()
        elseif procs.deferred then
            WTF.ApplyProcSounds()
        end
    end)
end
