local _, WTF = ...

-- Grimoire: reminders. Two click-to-cast icons and their alert lines:
--   armor  shown out of combat while neither Demon Armor nor Demon Skin is on
--          you; a click casts the best one you know. A line warns a minute
--          before it runs out (timed from the buff's end, read out of combat,
--          or from your own cast, which stays readable in combat).
--   demon  shown while you have no demon (or a dead one) and are not
--          mounted; the game's state driver decides, also in combat (no
--          reads, nothing secret, as Dyre's Buff Reminders does). A click
--          summons the last demon you summoned, else the Imp.
-- Buff reads happen only out of combat: on Forever addon code cannot read
-- auras in combat. Icons are secure buttons, so they change only out of combat.

local ARMORS = {
    {key = "armor", ids = {706, 1086, 11733, 11734, 11735}, label = "Demon Armor"},
    {key = "skin", ids = {687, 696}, label = "Demon Skin"},
}
-- Summon Imp, Voidwalker, Succubus, Felhunter.
local DEMONS = {
    {key = "imp", ids = {688}, label = "Summon Imp"},
    {key = "voidwalker", ids = {697}, label = "Summon Voidwalker"},
    {key = "succubus", ids = {712}, label = "Summon Succubus"},
    {key = "felhunter", ids = {691}, label = "Summon Felhunter"},
}
-- Demon Skin and Demon Armor last 30 minutes in Classic.
local ARMOR_SECONDS = 30 * 60
local EXPIRY_LEAD = 60
local REMIND_THROTTLE = 120
local REFRESH_DELAY = 0.2
-- After login the demon and the buffs take a moment to show up; no line
-- before then (the icons still update), and one refresh right after.
local LOGIN_QUIET = 10
local BUTTON_SIZE, BUTTON_GAP, PADDING = 36, 8, 4
local DEFAULT_POINT = {"CENTER", "CENTER", 0, 150}
local PET_DRIVER = "[mounted] hide; [nopet] show; [@pet,dead] show; hide"
local GOLD = {1, 0.82, 0}
local ICONS = {armor = "Interface\\Icons\\Spell_Shadow_RagingScream",
    demon = "Interface\\Icons\\Spell_Shadow_SummonImp"}

local reminders = {generation = 0, pending = false, names = {}, demonNames = {}}
local holder, buttons = nil, {}

function WTF.SanitizeReminders(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    return {
        armor = saved.armor ~= false,
        demon = saved.demon ~= false,
        position = sanitizePosition(saved.position),
        lastDemon = type(saved.lastDemon) == "string" and saved.lastDemon or nil,
    }
end

-- The spells you know, by family: the best armor, and each demon summon.
local function ReadSpells()
    local defs = {}
    for _, armor in ipairs(ARMORS) do
        defs[#defs + 1] = {key = armor.key, ids = armor.ids}
    end
    for _, demon in ipairs(DEMONS) do
        defs[#defs + 1] = {key = demon.key, ids = demon.ids}
    end
    local byID, _, known = WTF.shared.IndexSpells(defs)
    reminders.byID, reminders.known = byID, known
    reminders.armor = nil
    for _, armor in ipairs(ARMORS) do
        reminders.names[armor.key] = C_Spell.GetSpellName(armor.ids[1]) or armor.label
        if not reminders.armor and known[armor.key] then
            reminders.armor = armor
        end
    end
    reminders.anyDemon = false
    for _, demon in ipairs(DEMONS) do
        reminders.demonNames[demon.key] = C_Spell.GetSpellName(demon.ids[1]) or demon.label
        reminders.anyDemon = reminders.anyDemon or known[demon.key] == true
    end
end

-- The armor on you, out of combat only: its name and end time (0: none
-- readable), else nil.
local function ArmorOn()
    if type(C_UnitAuras) ~= "table" or type(C_UnitAuras.GetAuraDataBySpellName) ~= "function" then
        return nil
    end
    for _, armor in ipairs(ARMORS) do
        local name = reminders.names[armor.key]
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if ok and type(aura) == "table" then
            local ends = aura.expirationTime
            return name, (not WTF.IsSecret(ends) and type(ends) == "number") and ends or 0
        end
    end
    return nil
end

local function ArmorName()
    return reminders.armor and reminders.names[reminders.armor.key]
end

-- A warning a minute before the armor runs out; a newer cast or read
-- replaces it (generation).
local function ScheduleExpiry(ends)
    reminders.generation = reminders.generation + 1
    local generation = reminders.generation
    local wait = ends - GetTime() - EXPIRY_LEAD
    if ends <= 0 or wait <= 0 then
        return
    end
    C_Timer.After(wait, function()
        if generation == reminders.generation and WTF.db.reminders.armor and reminders.armor then
            WTF.Alert("armor:ending", ArmorName() .. " ends in 1 min.", "warn", {throttle = 30})
        end
    end)
end

-- The summon a click casts, and its spell ID for the icon.
local function DemonSpell()
    local last = WTF.db.reminders.lastDemon
    for _, demon in ipairs(DEMONS) do
        if reminders.demonNames[demon.key] == last and reminders.known[demon.key] then
            return last, demon.ids[1]
        end
    end
    for _, demon in ipairs(DEMONS) do
        if reminders.known[demon.key] then
            return reminders.demonNames[demon.key], demon.ids[1]
        end
    end
end

local function SpellIcon(id, fallback)
    local texture = id and type(C_Spell.GetSpellTexture) == "function" and C_Spell.GetSpellTexture(id)
    return texture or fallback
end

local function HasLiveDemon()
    return UnitExists("pet") and not UnitIsDead("pet")
end

local function Mounted()
    return type(IsMounted) == "function" and IsMounted() == true
end

-- Out of combat: reads, icons, and the reminder lines.
local function Apply()
    reminders.pending = false
    if not holder then
        return
    end
    ReadSpells()
    local settings = WTF.db.reminders
    local unlocked = not WTF.db.locked
    holder.mover:SetShown(unlocked)
    -- Armor.
    local armorButton = buttons.armor
    local armorName = ArmorName()
    local onName, ends = nil, 0
    if armorName then
        onName, ends = ArmorOn()
    end
    if onName and ends > 0 then
        ScheduleExpiry(ends)
    end
    local missing = settings.armor and armorName ~= nil and onName == nil
    armorButton:SetAttribute("type", "spell")
    armorButton:SetAttribute("spell", armorName)
    armorButton.icon:SetTexture(SpellIcon(reminders.armor and reminders.armor.ids[1], ICONS.armor))
    armorButton.label = armorName
    armorButton:SetShown(missing or unlocked)
    local quiet = GetTime() < (reminders.quietUntil or 0)
    if missing and not Mounted() and not quiet then
        WTF.Alert("armor", armorName .. " missing. Click the icon.", "warn", {throttle = REMIND_THROTTLE})
    end
    -- Demon.
    local demonButton = buttons.demon
    local summon, summonID = DemonSpell()
    demonButton.icon:SetTexture(SpellIcon(summonID, ICONS.demon))
    demonButton:SetAttribute("type", "spell")
    demonButton:SetAttribute("spell", summon)
    demonButton.label = summon
    local wanted = settings.demon and summon ~= nil
    RegisterStateDriver(demonButton, "visibility", unlocked and "show" or (wanted and PET_DRIVER or "hide"))
    if wanted and not HasLiveDemon() and not Mounted() and not quiet then
        WTF.Alert("demon", "No demon out. Click the icon to summon.", "warn", {throttle = REMIND_THROTTLE})
    end
end

-- Many events come in bursts; one refresh shortly after, out of combat.
function WTF.RefreshReminders()
    if not holder or reminders.pending then
        return
    end
    reminders.pending = true
    C_Timer.After(REFRESH_DELAY, function()
        WTF.shared.OutOfCombat(reminders, Apply)
    end)
end

local function OnCast(spellID)
    if WTF.IsSecret(spellID) or type(spellID) ~= "number" or not reminders.byID then
        return
    end
    local def = reminders.byID[spellID]
    if not def then
        local name = C_Spell.GetSpellName(spellID)
        for _, demon in ipairs(DEMONS) do
            if name and name == reminders.demonNames[demon.key] then
                def = demon
            end
        end
        if not def then
            return
        end
    end
    for _, demon in ipairs(DEMONS) do
        if def.key == demon.key then
            WTF.db.reminders.lastDemon = reminders.demonNames[demon.key]
            WTF.RefreshReminders()
            return
        end
    end
    -- An armor cast, also in combat: its full length from now.
    ScheduleExpiry(GetTime() + ARMOR_SECONDS)
end

local function ShowTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.label and ("Click: " .. button.label) or "Nothing to cast yet.", 1, 1, 1)
    if button.kind == "demon" then
        GameTooltip:AddLine("Summons your last demon. Shows while you have none.", 0.7, 0.7, 0.7, true)
    else
        GameTooltip:AddLine("Shows out of combat while your armor is missing.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end

local function CreateButton(kind, index)
    local button = CreateFrame("Button", "GrimoireReminder" .. (kind == "armor" and "Armor" or "Demon"), holder,
        "SecureActionButtonTemplate")
    button.kind = kind
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetPoint("LEFT", holder, "LEFT", PADDING + (index - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("useOnKeyDown", false)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon:SetTexture(ICONS[kind])
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", 3, -3)
    border:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10})
    border:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function() WTF.BeginDrag(holder) end)
    button:SetScript("OnDragStop", function() WTF.EndDrag(holder) end)
    button:Hide()
    return button
end

local function Place()
    local position = WTF.db.reminders.position
    holder:ClearAllPoints()
    if position then
        holder:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        holder:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[2], DEFAULT_POINT[3], DEFAULT_POINT[4])
    end
end

function WTF.ResetRemindersPosition()
    WTF.db.reminders.position = nil
    if holder then
        WTF.shared.OutOfCombat(holder, Place)
    end
end

function WTF.ReportRemindersDebug()
    local name, ends = nil, nil
    if holder and not InCombatLockdown() then
        name, ends = ArmorOn()
    end
    WTF.Report(string.format("debug_reminders armor=%s on=%s ends=%s demon=%s lastDemon=%s pet=%s",
        tostring(ArmorName()), tostring(name), tostring(ends and math.floor(ends - GetTime())),
        tostring(holder and DemonSpell()), tostring(WTF.db.reminders.lastDemon), tostring(UnitExists("pet"))))
end

function WTF.InitializeReminders()
    holder = CreateFrame("Frame", "GrimoireReminders", UIParent)
    holder:SetSize(PADDING * 2 + BUTTON_SIZE * 2 + BUTTON_GAP, BUTTON_SIZE + PADDING * 2)
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    holder:EnableMouse(false)
    WTF.RegisterMovable(holder, function(position) WTF.db.reminders.position = position end)
    holder.mover = WTF.CreateMover(holder)
    buttons.armor = CreateButton("armor", 1)
    buttons.demon = CreateButton("demon", 2)
    WTF.reminderButtons = buttons
    Place()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    events:RegisterUnitEvent("UNIT_AURA", "player")
    events:RegisterUnitEvent("UNIT_PET", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            OnCast(spellID)
        elseif not InCombatLockdown() then
            WTF.RefreshReminders()
        end
    end)
    ReadSpells()
    reminders.quietUntil = GetTime() + LOGIN_QUIET
    WTF.RefreshReminders()
    C_Timer.After(LOGIN_QUIET + 0.5, WTF.RefreshReminders)
end
