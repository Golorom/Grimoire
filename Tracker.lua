local _, WTF = ...

-- DoT tracker. Two pinned rows, your target (purple outline) and your focus
-- (red outline), each shown only while that unit is a live hostile; then a
-- list of the other mobs you DoTed, with a slot per spell family in its own
-- color, in the Compact or Bars theme (author-approved). Since 1.5.0 the
-- engine is Dyre's Toolkit's (DotTracker.lua's CreateDotTracker, 2.5.0, moved
-- from here; its header holds the rules) with ClassData.WARLOCK's slots. WTF
-- keeps its settings (db.tracker, repaired in Core), its three frame names,
-- the default place, its colors, and its Options page, and claims the
-- Warlock's DoTs at priority 10.

local TRACKER_PRIORITY = 10
local DEFAULT_POINT = {"CENTER", "CENTER", -260, 120}
local NAMES = {target = "GrimoireTracker", focus = "GrimoireTrackerFocus",
    list = "GrimoireTrackerList"}

-- The smart curse (John, 2026-11-10, from a player comment; Toolkit 2.7.0):
-- the engine's hidden secure button for a key binding (Bindings.xml), and
-- the "! Curse" macro with the same text.
local SMART_CURSE_BUTTON = "GrimoireSmartCurse"
local CURSE_MACRO = "! Curse"
BINDING_HEADER_GRIMOIRE = "Grimoire"
_G["BINDING_NAME_CLICK " .. SMART_CURSE_BUTTON .. ":LeftButton"] = "Smart curse"

local tracker = {available = false}

function WTF.CheckTrackerCapabilities()
    -- Forever's engine aura slots, else the Toolkit's plain-Lua ones (Auras.lua).
    if not WTF.AuraEngineKind() then
        return false, WTF.AURA_ENGINE_MISSING
    end
    for _, name in ipairs({"RegisterStateDriver", "UnregisterStateDriver"}) do
        if type(_G[name]) ~= "function" then
            return false, name
        end
    end
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
        return false, "C_Timer.After"
    end
    return true
end

-- The engine's tracker, once made; Dots.lua and Predict.lua use it too.
function WTF.DotTracker()
    return tracker.available and tracker.engine or nil
end

function WTF.TrackerCandidateFilters(key)
    return tracker.available and tracker.engine:CandidateFilters(key) or nil
end

function WTF.TrackerKnowsSlot(key)
    return tracker.available and tracker.engine:KnowsSlot(key) or false
end

function WTF.TrackerSlotIcon(key)
    return tracker.available and tracker.engine:SlotIcon(key) or nil
end

local function Rebuild()
    if tracker.available then
        tracker.engine:Rebuild()
    end
end

WTF.ApplyDotOrder = Rebuild
WTF.ApplyTrackerColors = Rebuild

function WTF.ApplyPanelColors()
    if tracker.available then
        tracker.engine:ApplyPanelColors()
    end
end

function WTF.RefreshTrackerPrediction(guid)
    if tracker.available then
        tracker.engine:RefreshPrediction(guid)
    end
end

function WTF.SetTrackerHealth(key, value)
    local settings = WTF.db.tracker
    if key == "health" then
        settings.health = value == true
    elseif key == "healthText" then
        settings.healthText = WTF.SanitizeHealthText(value)
    end
    Rebuild()
end

function WTF.SetTrackerSize(theme, key, value)
    local sizes = WTF.db.tracker.sizes
    if key then
        local saved = {}
        for name, current in pairs(sizes[theme]) do
            saved[name] = current
        end
        saved[key] = value
        sizes[theme] = WTF.SanitizeTrackerSizes(theme, saved)
    else
        sizes[theme] = WTF.SanitizeTrackerSizes(theme, nil)
    end
    Rebuild()
end

function WTF.SetTrackerTheme(theme)
    WTF.db.tracker.theme = theme == "bars" and "bars" or "compact"
    Rebuild()
end

function WTF.SetTrackerStyle(style)
    WTF.db.tracker.style = WTF.SanitizeChoice(style, WTF.FRAME_STYLES, "dyre")
    WTF.ApplyPanelColors()
end

function WTF.SetTrackerPanelOpacity(key, percent)
    WTF.db.tracker.panelOpacity[key] = WTF.SanitizeWhole(percent, WTF.PANEL_OPACITY_MIN, WTF.PANEL_OPACITY_MAX,
        WTF.DEFAULT_PANEL_OPACITY)
    if tracker.available then
        tracker.engine:ApplyPanelOpacity()
    end
end

-- Whether the Toolkit has the smart curse (2.7.0 or later).
function WTF.SmartCurseAvailable()
    return tracker.available and type(tracker.engine.ApplySmartCurse) == "function"
end

-- "! Curse": written while the control macros are on and you know Curse of
-- Weakness; deleted when they are off, and when you lose Weakness (only one
-- this session wrote). Out of combat (in combat, when it ends).
local function WriteCurseMacro(body)
    local keeper = tracker.keeper
    if not keeper then
        return
    end
    WTF.shared.OutOfCombat(keeper, function()
        if WTF.db.control.macros == false then
            keeper:Delete(CURSE_MACRO)
        elseif body then
            keeper:Write(CURSE_MACRO, body)
        elseif keeper.written[CURSE_MACRO] then
            keeper:Delete(CURSE_MACRO)
        end
    end)
end

function WTF.ApplyCurseMacro()
    if WTF.SmartCurseAvailable() then
        WriteCurseMacro(tracker.engine:SmartCurseBody())
    end
end

function WTF.SetCurseMode(mode)
    WTF.db.tracker.curseMode = mode == "smart" and "smart" or "last"
    if WTF.SmartCurseAvailable() then
        tracker.engine:ApplySmartCurse()
    end
end

function WTF.SetCurseMarker(on)
    WTF.db.tracker.curseMarker = on ~= false
    if WTF.SmartCurseAvailable() then
        tracker.engine:ApplySmartCurse()
    end
end

-- Whether the engine draws the outline at a set width (Toolkit 2.8.0 or later).
function WTF.TrackerOutlineAvailable()
    local toolkit = WTF.engine and WTF.engine.toolkit
    return type(toolkit) == "table" and type(toolkit.TRACKER_OUTLINE) == "table"
end

-- Out of combat; in combat the engine rebuilds when combat ends.
function WTF.SetTrackerOutlineWidth(width)
    WTF.db.tracker.outlineWidth = WTF.SanitizeWhole(width, WTF.OUTLINE_WIDTH_MIN, WTF.OUTLINE_WIDTH_MAX,
        WTF.DEFAULT_OUTLINE_WIDTH)
    Rebuild()
end

function WTF.ResetTrackerPosition()
    WTF.db.tracker.position = nil
    WTF.db.tracker.sections = {}
    if tracker.available then
        tracker.engine:ResetPosition()
    end
end

function WTF.RefreshTracker()
    if tracker.available then
        tracker.engine:Refresh()
    end
end

-- The engine's three parts in Edit Mode. Focus and list default to stacked
-- under the target part; Reset Position puts them a little below it.
local SECTION_INFO = {
    [NAMES.target] = {name = "Grimoire DoT tracker", y = 0},
    [NAMES.focus] = {name = "Grimoire DoT tracker focus", y = -60},
    [NAMES.list] = {name = "Grimoire DoT tracker list", y = -120},
}

-- Each part's Edit Mode dialog (0.3.5, moved from the settings page): first
-- the look all three parts share (theme, sizes, outline, mob health), then
-- the part's own color and opacity. Sizes and the name position act on the
-- theme in use. A change in combat applies when combat ends.
local PANEL_OF = {[NAMES.target] = "target", [NAMES.focus] = "focus", [NAMES.list] = "list"}
local SHARED = " Shared by all three parts of the DoT tracker."
local THEMES = {{key = "compact", label = "Compact"}, {key = "bars", label = "Bars"}}

local function Values(list)
    local values = {}
    for _, choice in ipairs(list) do
        values[#values + 1] = {text = choice.label, value = choice.key}
    end
    return values
end

local function Spec(theme, key)
    for _, spec in ipairs(WTF.TRACKER_SIZE_SPECS[theme]) do
        if spec.key == key then
            return spec
        end
    end
end

local function SizeSetting(kinds, theme, key)
    local spec = Spec(theme or "compact", key)
    local store = WTF.db.tracker
    return {kind = kinds.Slider, name = spec.label, default = spec.default, minValue = spec.min,
        maxValue = spec.max, valueStep = spec.step,
        get = function() return store.sizes[theme or store.theme][key] end,
        set = function(_, value) WTF.SetTrackerSize(theme or store.theme, key, value) end,
        hidden = theme and function() return store.theme ~= theme end or nil,
        desc = (spec.tooltip or ("In the " .. (theme == "bars" and "Bars" or theme and "Compact" or "current")
            .. " theme.")) .. SHARED}
end

local function SectionSettings(frame, panel)
    local store = WTF.db.tracker
    local colors = {}
    for _, entry in ipairs(WTF.TRACKER_PANEL_COLORS) do
        colors[entry.key] = entry
    end
    local name = ({target = "target panel", focus = "focus panel", list = "other mobs' panel"})[panel]
    WTF.AddEditModeSettings(frame, function(kinds)
        local list = {
            {kind = kinds.Dropdown, name = "Theme", default = "compact", values = Values(THEMES),
                get = function() return store.theme end, set = function(_, value) WTF.SetTrackerTheme(value) end,
                desc = "Compact: a row per mob with an icon per spell. Bars: a block per mob with a bar per spell "
                    .. "you know, draining as its time runs out." .. SHARED},
            {kind = kinds.Dropdown, name = "Style", default = "dyre", values = Values(WTF.FRAME_STYLES),
                get = function() return store.style end, set = function(_, value) WTF.SetTrackerStyle(value) end,
                desc = "Dyre's: each row's border in its panel's color. Gold rim: a gold border, as the game's own "
                    .. "frames have; the target and focus outlines keep their colors." .. SHARED},
            SizeSetting(kinds, "compact", "iconSize"),
            SizeSetting(kinds, "compact", "nameWidth"),
            SizeSetting(kinds, "bars", "barWidth"),
            SizeSetting(kinds, "bars", "lineHeight"),
            SizeSetting(kinds, nil, "textScale"),
            {kind = kinds.Dropdown, name = "Name position", default = "left",
                values = function() return Values(WTF.TRACKER_NAME_POSITIONS[store.theme]) end,
                get = function() return store.sizes[store.theme].namePosition end,
                set = function(_, value) WTF.SetTrackerSize(store.theme, "namePosition", value) end,
                desc = "Where the mob's name sits in each row." .. SHARED},
        }
        if panel ~= "list" and WTF.TrackerOutlineAvailable() then
            list[#list + 1] = {kind = kinds.Slider, name = "Outline", default = WTF.DEFAULT_OUTLINE_WIDTH,
                minValue = WTF.OUTLINE_WIDTH_MIN, maxValue = WTF.OUTLINE_WIDTH_MAX, valueStep = 1,
                get = function() return store.outlineWidth end,
                set = function(_, value) WTF.SetTrackerOutlineWidth(value) end,
                desc = "How thick the solid outline around the target and focus rows is, in pixels. 0 hides it."}
        end
        list[#list + 1] = {kind = kinds.Checkbox, name = "Show mob health", default = false,
            get = function() return store.health end, set = function(_, value) WTF.SetTrackerHealth("health", value) end,
            desc = "Each mob's name line is its health bar, in the panel's color." .. SHARED}
        list[#list + 1] = {kind = kinds.Dropdown, name = "Health text", default = "none",
            values = Values(WTF.TRACKER_HEALTH_TEXTS),
            get = function() return store.healthText end,
            set = function(_, value) WTF.SetTrackerHealth("healthText", value) end,
            hidden = function() return not store.health end,
            desc = "The mob's health as text after its name: its number, its percent, or both." .. SHARED}
        if kinds.ColorPicker and type(CreateColor) == "function" then
            local entry = colors[panel]
            list[#list + 1] = {kind = kinds.ColorPicker, name = "Color", default = CreateColor(WTF.HexToRGB(entry.color)),
                get = function() return CreateColor(WTF.HexToRGB(store.panelColors[panel])) end,
                set = function(_, color)
                    store.panelColors[panel] = WTF.RGBToHex(color:GetRGB())
                    WTF.ApplyPanelColors()
                end,
                desc = panel == "list" and "The row border and health fill of the other mobs' rows."
                    or "The outline and health fill of the " .. name .. "."}
        end
        list[#list + 1] = {kind = kinds.Slider, name = "Opacity", default = WTF.DEFAULT_PANEL_OPACITY,
            minValue = WTF.PANEL_OPACITY_MIN, maxValue = WTF.PANEL_OPACITY_MAX, valueStep = 5,
            get = function() return store.panelOpacity[panel] end,
            set = function(_, value) WTF.SetTrackerPanelOpacity(panel, value) end,
            desc = "How solid the " .. name .. " is, rows and all, in percent."}
        return list
    end)
end

local function RegisterSection(frame, save)
    local info = SECTION_INFO[frame:GetName()] or {name = frame:GetName(), y = 0}
    WTF.RegisterMovable(frame, save, {name = info.name,
        default = {point = DEFAULT_POINT[1], x = DEFAULT_POINT[3], y = DEFAULT_POINT[4] + info.y}})
    if PANEL_OF[frame:GetName()] then
        SectionSettings(frame, PANEL_OF[frame:GetName()])
    end
end

function WTF.InitializeTracker()
    local available, missing = WTF.CheckTrackerCapabilities()
    if not available then
        WTF.Report("The DoT tracker stays off: this client lacks " .. missing .. ".")
        return
    end
    local engine, why = WTF.shared.CreateDotTracker({
        addon = "Grimoire",
        priority = TRACKER_PRIORITY,
        class = "WARLOCK",
        store = WTF.db.tracker,
        names = {target = NAMES.target, focus = NAMES.focus, list = NAMES.list, smartCurse = SMART_CURSE_BUTTON},
        point = DEFAULT_POINT,
        slotColor = WTF.SlotColor,
        panelColor = WTF.PanelColor,
        -- 0.3.5: the gold rim style colors every row's border gold.
        borderColor = function()
            if WTF.db.tracker.style == "gold" then
                return WTF.GOLD_RIM
            end
        end,
        -- Each part moves in Edit Mode (EditMode.lua) under its own name.
        movable = {register = RegisterSection, beginDrag = WTF.BeginDrag, endDrag = WTF.EndDrag},
        locked = function() return WTF.db.locked ~= false end,
        -- The Toolkit's Ctrl-drag of a locked frame; Edit Mode does the moving.
        ctrlMove = false,
        predictor = WTF.predictor,
        onSpellsChanged = function() WTF.RefreshPlateDots() end,
        onSmartCurse = function(body) WriteCurseMacro(body) end,
    })
    if not engine then
        WTF.Report("The DoT tracker stays off: this client lacks " .. tostring(why) .. ".")
        return
    end
    tracker.engine = engine
    tracker.available = true
    if WTF.SmartCurseAvailable() then
        tracker.keeper = WTF.shared.CreateMacroKeeper({warn = WTF.Warn})
        WTF.ApplyCurseMacro()
    end
end

function WTF.ReportTrackerDebug()
    local available, missing = WTF.CheckTrackerCapabilities()
    WTF.Report(string.format("debug_tracker available=%s%s", tostring(available and tracker.available),
        missing and (" missing=" .. missing) or ""))
    if not tracker.available then
        return
    end
    for _, line in ipairs(tracker.engine:DebugLines()) do
        WTF.Report("debug_tracker " .. line)
    end
end
