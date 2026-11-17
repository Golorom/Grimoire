local _, WTF = ...

-- Glows on your action bars (0.3.6): the button that holds what Grimoire
-- wants you to press glows, so your bars can be the whole control and
-- Grimoire's own buttons and strip can be hidden. Each kind has a switch:
--   stones     a stone you can make (as the Stones buttons glow): the
--              "! Healthstone" and "! Soulstone" macros, the Create spells,
--              the stones themselves
--   armor      Demon Armor or Demon Skin while it is missing
--   demon      your last demon's summon while none is out
--   recast     a DoT due again on your target (the spell, or a macro that
--              casts it), or on your focus (the "! <DoT> F" macros)
--   nightfall  Shadow Bolt while Shadow Trance is up. Addon code cannot
--              read buffs in combat, so the game's aura engine draws this
--              glow, as it draws the Nightfall icon.
-- Which button holds what is read out of combat, when bars, macros or
-- spells change. The glows are plain frames that show and hide at once,
-- also in combat.

local BUTTON_NAMES = {"ActionButton%d", "MultiBarBottomLeftButton%d", "MultiBarBottomRightButton%d",
    "MultiBarRightButton%d", "MultiBarLeftButton%d", "MultiBar5Button%d", "MultiBar6Button%d",
    "MultiBar7Button%d"}
local BUTTONS_PER_BAR = 12
local MAP_DELAY = 0.2
local SHADOW_BOLT = 686
local NIGHTFALL_GLOWS = 6
-- Which switch each kind of want belongs to. The prep macro always glows
-- while it has a step (0.4.0).
local SWITCH = {healthstone = "healthstone", soulstone = "soulstone", armor = "armor", summon = "demon",
    dot = "recast", focus = "recast"}
local MAP_JOB = {}

local hotbar = {keysOf = {}, wants = {}, glowing = {}, proxies = {}}

function WTF.SanitizeHotbar(saved)
    saved = type(saved) == "table" and saved or {}
    local clean = {}
    for _, key in ipairs({"armor", "demon", "recast", "nightfall"}) do
        clean[key] = saved[key] ~= false
    end
    -- 0.4.0: a switch per stone (0.3.6 had one for both, "stones").
    for _, key in ipairs({"healthstone", "soulstone"}) do
        if type(saved[key]) == "boolean" then
            clean[key] = saved[key]
        else
            clean[key] = saved.stones ~= false
        end
    end
    clean.focusMacros = saved.focusMacros == true
    clean.prepMacro = saved.prepMacro == true
    return clean
end

local function Buttons()
    local list = {}
    for _, pattern in ipairs(BUTTON_NAMES) do
        for index = 1, BUTTONS_PER_BAR do
            local button = _G[pattern:format(index)]
            if type(button) == "table" then
                list[#list + 1] = button
            end
        end
    end
    return list
end

local function SlotOf(button)
    if type(button.action) == "number" then
        return button.action
    end
    local slot = type(button.GetAttribute) == "function" and button:GetAttribute("action")
    return type(slot) == "number" and slot or nil
end

local function SpellName(spellID)
    return WTF.shared and type(WTF.shared.SpellName) == "function" and WTF.shared.SpellName(spellID) or nil
end

-- What a spell is to Grimoire, as want keys.
local function SpellKeys(spellID, keys)
    if type(spellID) ~= "number" or WTF.IsSecret(spellID) then
        return
    end
    local stone = WTF.StoneOfAction and WTF.StoneOfAction("spell", spellID)
    if stone then
        keys[stone] = true
    end
    local name = SpellName(spellID)
    if name == "Demon Armor" or name == "Demon Skin" then
        keys.armor = true
    end
    if name then
        keys["summon:" .. name] = true
    end
    if spellID == SHADOW_BOLT or name == SpellName(SHADOW_BOLT) then
        keys.shadowBolt = true
    end
    local family = WTF.RecastFamilyOf and WTF.RecastFamilyOf(spellID)
    if family then
        keys["dot:" .. family] = true
    end
end

-- The want keys of an action slot: the spell, item, or macro in it.
local function KeysOf(slot)
    local keys = {}
    if type(GetActionInfo) ~= "function" then
        return keys
    end
    local kind, id, subType = GetActionInfo(slot)
    if kind == "spell" then
        SpellKeys(id, keys)
    elseif kind == "item" then
        local stone = WTF.StoneOfAction and WTF.StoneOfAction("item", id)
        if stone then
            keys[stone] = true
        end
    elseif kind == "macro" then
        local name = type(GetActionText) == "function" and GetActionText(slot) or nil
        if name == WTF.PREP_MACRO then
            keys.prep = true
            return keys
        end
        local focus = name and WTF.FocusMacroFamily and WTF.FocusMacroFamily(name)
        if focus then
            -- A focus macro glows for the focus only.
            keys["focus:" .. focus] = true
            return keys
        end
        local stone = name and WTF.StoneOfAction and WTF.StoneOfAction("macro", name)
        if stone then
            keys[stone] = true
        end
        local spellID
        if subType == "spell" then
            spellID = id
        elseif type(GetMacroSpell) == "function" and type(id) == "number" then
            spellID = GetMacroSpell(id)
        end
        SpellKeys(spellID, keys)
    end
    return keys
end

local function On(key)
    local switch = SWITCH[key:match("^(%a+)")]
    return switch == nil or WTF.db.hotbar[switch] == true
end

local function Wanted(keys)
    for _, group in pairs(hotbar.wants) do
        for key in pairs(group) do
            if keys[key] and On(key) then
                return true
            end
        end
    end
    return false
end

-- Each mapped button's glow, shown or hidden. Plain frames: also in combat.
local function Apply()
    for button, keys in pairs(hotbar.keysOf) do
        local on = Wanted(keys)
        if on or button.grimoireGlow then
            if on and not button.grimoireGlow and not InCombatLockdown() then
                button.grimoireGlow = WTF.CreateGlow(button)
            end
            WTF.SetGlow(button.grimoireGlow, on)
            hotbar.glowing[button] = on or nil
        end
    end
end

-- Shadow Bolt's buttons get the game-drawn Nightfall glow: a plain frame
-- over each, holding an aura slot that shows only while the buff is up.
local function PlaceNightfall(bolts)
    local on = WTF.db.hotbar.nightfall
    for index, proxy in ipairs(hotbar.proxies) do
        local button = bolts[index]
        proxy:ClearAllPoints()
        if on and button then
            proxy:SetAllPoints(button)
            proxy:SetFrameStrata(button:GetFrameStrata())
            proxy:SetFrameLevel(math.min(button:GetFrameLevel() + 10, 10000))
            proxy:Show()
        else
            proxy:Hide()
        end
    end
end

-- 0.3.8: a small red F on a button that holds a focus macro, so it reads
-- apart from the same spell for your target. A plain frame on the button.
local FOCUS_RED = {1, 0.25, 0.2}

local function FocusMark(button, shown)
    local mark = button.grimoireFocusMark
    if not mark and shown then
        mark = CreateFrame("Frame", nil, button)
        mark:SetAllPoints(button)
        mark:EnableMouse(false)
        mark:SetFrameLevel(math.min(button:GetFrameLevel() + 5, 10000))
        mark.text = mark:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mark.text:SetPoint("TOPLEFT", mark, "TOPLEFT", 2, -2)
        local font, size = mark.text:GetFont()
        if font then
            mark.text:SetFont(font, size, "OUTLINE")
        end
        mark.text:SetTextColor(FOCUS_RED[1], FOCUS_RED[2], FOCUS_RED[3])
        mark.text:SetText("F")
        button.grimoireFocusMark = mark
    end
    if mark then
        mark:SetShown(shown)
    end
end

local function IsFocus(keys)
    for key in pairs(keys) do
        if key:match("^focus:") then
            return true
        end
    end
    return false
end

-- Out of combat: which button holds what. Glows are made here, so a glow
-- that turns on in combat already has its frame.
local function Map()
    local keysOf, bolts = {}, {}
    for _, button in ipairs(Buttons()) do
        local slot = SlotOf(button)
        if slot and (type(HasAction) ~= "function" or HasAction(slot)) then
            local keys = KeysOf(slot)
            if next(keys) then
                keysOf[button] = keys
                if not button.grimoireGlow then
                    button.grimoireGlow = WTF.CreateGlow(button)
                end
                if keys.shadowBolt then
                    bolts[#bolts + 1] = button
                end
            end
        end
    end
    for button in pairs(hotbar.glowing) do
        if not keysOf[button] then
            WTF.SetGlow(button.grimoireGlow, false)
            hotbar.glowing[button] = nil
        end
    end
    for _, button in ipairs(Buttons()) do
        FocusMark(button, keysOf[button] ~= nil and IsFocus(keysOf[button]))
    end
    hotbar.keysOf = keysOf
    hotbar.bolts = bolts
    PlaceNightfall(bolts)
    Apply()
end

function WTF.RefreshHotbar()
    if not hotbar.started then
        return
    end
    if WTF.shared then
        WTF.shared.OutOfCombat(MAP_JOB, Map)
    elseif not InCombatLockdown() then
        Map()
    end
end

-- A source's wants, as a set of keys; the group replaces its last set.
function WTF.SetHotbarGroup(group, keys)
    local old = hotbar.wants[group] or {}
    local same = true
    for key in pairs(keys) do
        if not old[key] then
            same = false
        end
    end
    for key in pairs(old) do
        if not keys[key] then
            same = false
        end
    end
    if same then
        return
    end
    hotbar.wants[group] = keys
    Apply()
end

-- One want that is its own group (a stone, the armor).
function WTF.SetHotbarWant(key, on)
    WTF.SetHotbarGroup(key, on and {[key] = true} or {})
end

-- The glows now: button names, for tests and /grim debug_hotbar.
function WTF.HotbarGlows()
    local names = {}
    for button, on in pairs(hotbar.glowing) do
        if on then
            names[#names + 1] = button:GetName() or "?"
        end
    end
    table.sort(names)
    return names
end

function WTF.ReportHotbarDebug()
    local mapped = 0
    for _ in pairs(hotbar.keysOf) do
        mapped = mapped + 1
    end
    local wants = {}
    for _, group in pairs(hotbar.wants) do
        for key in pairs(group) do
            wants[#wants + 1] = key
        end
    end
    table.sort(wants)
    WTF.Report(string.format("debug_hotbar mapped=%d shadowBolt=%d wants=%s glowing=%s", mapped,
        #(hotbar.bolts or {}), table.concat(wants, ","), table.concat(WTF.HotbarGlows(), ",")))
end

-- Focus macros (0.3.6, a choice, off by default): "! Corruption F" and the
-- others cast that spell on your focus, for the spells you know. A DoT's
-- button glows when your focus needs that DoT again. Out of combat; off
-- deletes them. 0.4.0: "! Fear F" fears your focus (no glow).
local FEAR_IDS = {5782, 6213, 6215}
local FOCUS_MACROS = {
    {family = "corruption", slot = "corruption", name = "! Corruption F"},
    {family = "immolate", slot = "immolate", name = "! Immolate F"},
    {family = "agony", slot = "bane", name = "! Agony F"},
    {family = "siphon", slot = "siphon", name = "! Siphon F"},
    {family = "fear", ids = FEAR_IDS, cast = FEAR_IDS[1], name = "! Fear F"},
}
WTF.FOCUS_MACROS = FOCUS_MACROS

function WTF.FocusMacroFamily(name)
    for _, def in ipairs(FOCUS_MACROS) do
        if def.name == name then
            return def.family
        end
    end
end

local function DotSlot(key)
    local toolkit = WTF.engine and WTF.engine.toolkit
    local data = type(toolkit) == "table" and type(toolkit.ClassData) == "table" and toolkit.ClassData.WARLOCK
    for _, slot in ipairs(data and data.dots or {}) do
        if slot.key == key then
            return slot
        end
    end
end

function WTF.FocusMacroBody(spell)
    return "#showtooltip " .. spell .. "\n/cast [@focus,harm,nodead] " .. spell
end

local MACRO_JOB = {}
local function WriteFocusMacros()
    if not (WTF.CharacterMacrosAvailable and WTF.CharacterMacrosAvailable()) or not WTF.shared then
        return
    end
    for _, def in ipairs(FOCUS_MACROS) do
        -- A DoT's ranks come from its tracker slot; Fear carries its own.
        local slot = def.ids and def or DotSlot(def.slot)
        local known = slot and WTF.shared.KnowsAny(slot.ids)
        local spell = known and SpellName(slot.cast)
        if WTF.db.hotbar.focusMacros and spell then
            WTF.WriteCharacterMacro(def.name, WTF.FocusMacroBody(spell))
        else
            WTF.DeleteCharacterMacro(def.name)
        end
    end
end

function WTF.ApplyFocusMacros()
    if WTF.shared then
        WTF.shared.OutOfCombat(MACRO_JOB, WriteFocusMacros)
    end
end

-- The prep macro (0.3.8, a choice, off by default): "! Prep" does the next
-- missing step before a pull: summon your demon, then your armor, then a
-- Healthstone, then a Soulstone, each only when you carry none and can make
-- one. Rewritten out of combat as things change; it glows while a step is
-- due. With nothing to do, a press does nothing.
WTF.PREP_MACRO = "! Prep"
local PREP_ORDER = {"demon", "armor", "healthstone", "soulstone"}
local prep = {steps = {}}
local PREP_JOB = {}

function WTF.PrepMacroBody(spell)
    if not spell then
        return "#showtooltip"
    end
    return "#showtooltip " .. spell .. "\n/cast " .. spell
end

local function NextStep()
    for _, step in ipairs(PREP_ORDER) do
        if prep.steps[step] then
            return step, prep.steps[step]
        end
    end
end

local function WritePrepMacro()
    if not (WTF.CharacterMacrosAvailable and WTF.CharacterMacrosAvailable()) then
        return
    end
    if not WTF.db.hotbar.prepMacro then
        WTF.DeleteCharacterMacro(WTF.PREP_MACRO)
        prep.written = nil
        return
    end
    local _, spell = NextStep()
    local body = WTF.PrepMacroBody(spell)
    if body ~= prep.written then
        WTF.WriteCharacterMacro(WTF.PREP_MACRO, body)
        prep.written = body
    end
end

function WTF.ApplyPrepMacro()
    if WTF.shared then
        WTF.shared.OutOfCombat(PREP_JOB, WritePrepMacro)
    elseif not InCombatLockdown() then
        WritePrepMacro()
    end
end

-- A step and the spell that does it, or nil when it is not due.
function WTF.SetPrepStep(step, spell)
    if prep.steps[step] == spell then
        return
    end
    prep.steps[step] = spell
    WTF.SetHotbarWant("prep", NextStep() ~= nil)
    if WTF.db.hotbar.prepMacro then
        WTF.ApplyPrepMacro()
    end
end

function WTF.PrepStep()
    return NextStep()
end

local function CreateNightfallGlows()
    if not (WTF.AuraEngineKind and WTF.AuraEngineKind()) or not WTF.NightfallIDs then
        return
    end
    local ids = {}
    for _, id in ipairs(WTF.NightfallIDs()) do
        ids[id] = true
    end
    for index = 1, NIGHTFALL_GLOWS do
        local proxy = CreateFrame("Frame", nil, UIParent)
        proxy:EnableMouse(false)
        proxy:Hide()
        local container = WTF.shared.CreateAuraContainer(proxy)
        container:SetPoint("TOPLEFT")
        container:SetSize(1, 1)
        container:AddAuraSlot("nightfall", "HELPFUL", {
            candidateFilters = {includeSpellIDs = ids},
            initializeFrame = function(button)
                button:ClearAllPoints()
                button:SetAllPoints(proxy)
                button:SetMouseClickEnabled(false)
                WTF.SetGlow(WTF.CreateGlow(button), true)
            end,
        })
        container:SetUnit("player")
        proxy.container = container
        hotbar.proxies[index] = proxy
    end
end

function WTF.InitializeHotbar()
    hotbar.started = true
    CreateNightfallGlows()
    local events = CreateFrame("Frame")
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
            "UPDATE_BONUS_ACTIONBAR", "UPDATE_MACROS", "SPELLS_CHANGED"}) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            WTF.ApplyFocusMacros()
            WTF.ApplyPrepMacro()
        end
        -- Bursts of slot changes: one map shortly after, out of combat.
        if hotbar.pending then
            return
        end
        hotbar.pending = true
        C_Timer.After(MAP_DELAY, function()
            hotbar.pending = false
            WTF.RefreshHotbar()
        end)
    end)
    WTF.RefreshHotbar()
end
