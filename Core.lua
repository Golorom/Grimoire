local addonName, WTF = ...

-- Grimoire: a personal fork of Warlock Tools Forever 1.8.0 by Dyre (John
-- Bedworth, MIT), with Dyre's Toolkit 2.9.2's engines in Engine\ and without
-- the announcements, the Toolkit's layout and settings home, and the notes
-- about Dyre's other AddOns. Internal names stay WTF's, so upstream changes
-- still compare line by line.
local DEFAULT_TITLE = "Grimoire"
local READY_MESSAGE = "  Ready. Type /grim to open the settings."
local SLASH_KEY = "GRIMOIRE"
local PRIMARY_SLASH = "/grim"
local BACKUP_SLASH = "/grimoire"
local MAX_SLASH_ALIASES = 10
WTF.available = false

function WTF.Report(message)
    DEFAULT_CHAT_FRAME:AddMessage("Grimoire: " .. tostring(message))
end

-- An action that failed: said in chat and in red at the top of the screen,
-- so a click never fails silently (author-approved, as MTF does).
local WARNING_COLOR = {1, 0.1, 0.1}

function WTF.Warn(message)
    WTF.Report(message)
    if type(UIErrorsFrame) == "table" and type(UIErrorsFrame.AddMessage) == "function" then
        UIErrorsFrame:AddMessage("Grimoire: " .. tostring(message), WARNING_COLOR[1], WARNING_COLOR[2], WARNING_COLOR[3])
    end
end

-- Combat data can be a secret value on the target client: code may store and
-- pass it on, but never compare, concatenate, or print it.
function WTF.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

-- Text for diagnostics that never touches a secret value's contents.
function WTF.Describe(value)
    if WTF.IsSecret(value) then
        return "secret"
    end
    return tostring(value)
end

-- When the client refuses AddOn item moves and deletion, also from a key
-- press (found in client: DeleteCursorItem raised ADDON_ACTION_BLOCKED in a
-- dungeon, BugGrabber 6x): in combat, while the player affects combat (a secret
-- answer counts), or under a Combat, Encounter, ChallengeMode, PvPMatch, or
-- Map AddOn restriction. Shard deletion and the Healthstone trade check it at
-- each call and wait instead.
local MOVE_RESTRICTIONS = {"Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map"}

function WTF.MoveRestricted()
    if InCombatLockdown() then
        return true
    end
    if type(UnitAffectingCombat) == "function" then
        local affecting = UnitAffectingCombat("player")
        if WTF.IsSecret(affecting) or affecting then
            return true
        end
    end
    local kinds = type(Enum) == "table" and Enum.AddOnRestrictionType
    if type(C_RestrictedActions) ~= "table" or type(C_RestrictedActions.IsAddOnRestrictionActive) ~= "function"
        or type(kinds) ~= "table" then
        return false
    end
    for _, name in ipairs(MOVE_RESTRICTIONS) do
        if kinds[name] ~= nil and C_RestrictedActions.IsAddOnRestrictionActive(kinds[name]) == true then
            return true
        end
    end
    return false
end

-- Reads TOC fields so the banner follows the packaged version; never gates operations.
local function Metadata(field)
    if type(C_AddOns) ~= "table" or type(C_AddOns.GetAddOnMetadata) ~= "function" then
        return nil
    end
    local value = C_AddOns.GetAddOnMetadata(addonName, field)
    if type(value) == "string" and value:find("%S") then
        return value
    end
end

local function ReportLoaded(available)
    local banner = Metadata("Title") or DEFAULT_TITLE
    local version, author = Metadata("Version"), Metadata("Author")
    if version then
        banner = banner .. " " .. version
    end
    if author then
        banner = banner .. " by " .. author
    end
    WTF.Report(banner)
    if available then
        WTF.Report(READY_MESSAGE)
    end
end

-- Functions other runtime files must define. A mixed install of old and new
-- files otherwise fails silently, because the client hides Lua errors by default.
local REQUIRED_NAMESPACE = {
    "ParseCommand", "HandleCommand",
    "CheckShardCapabilities", "InitializeShards", "ReportShardStatus", "ReportShardDebug",
    "DebugDeleteShard", "RefreshShardCounter", "ResetShardCounterPosition",
    "CheckStoneCapabilities", "InitializeStones", "ResetStonesPosition", "ReportStoneDebug", "RefreshStonesMover",
    "ReportStoneStatus", "RemindStones", "ApplyStoneMacros", "AddInputHandler", "RunOnNextInput", "ReportClickDebug",
    "Warn", "RegisterMovable", "BeginDrag", "EndDrag", "ScaleKeepingCenter",
    "CharacterMacrosAvailable", "WriteCharacterMacro",
    "DeleteCharacterMacro", "ApplyControlMacros",
    "InitializeControl", "RefreshControl", "ResetControlPosition", "ReportControlDebug", "SanitizeControl",
    "CheckTrackerCapabilities", "InitializeTracker", "ResetTrackerPosition", "RefreshTracker",
    "ReportTrackerDebug", "TrackerCandidateFilters", "TrackerKnowsSlot", "SetTrackerTheme",
    "InitializePlateDots", "RefreshPlateDots", "HasTrackableDots", "ApplyTrackerColors", "ApplyDotColors",
    "InitializePredict", "RefreshPredict", "PredictAvailable", "ReportPredictDebug", "DotTracker",
    "SmartCurseAvailable", "ApplyCurseMacro", "SetCurseMode", "SetCurseMarker",
    "SetStonesScale", "SetShardCounterScale",
    "TrackerOutlineAvailable", "SetTrackerOutlineWidth",
    "RefreshTrackerPrediction",
    "ReportRestrictions", "ResetFocusWorks", "InitializeProbe", "InitializeOptions", "OpenSettings",
    "SanitizeAlerts", "InitializeAlerts", "RefreshAlerts", "Alert", "TestAlerts", "ResetAlertsPosition",
    "SanitizeReminders", "InitializeReminders", "RefreshReminders", "ResetRemindersPosition",
    "SanitizeThreat", "InitializeThreat", "SanitizePet", "InitializePet",
    "SanitizeProcs", "InitializeProcs", "RefreshProcs", "ResetProcsPosition",
    "SanitizeCooldowns", "InitializeCooldowns",
}

local function CheckInstalledFiles()
    for _, name in ipairs(REQUIRED_NAMESPACE) do
        if type(WTF[name]) ~= "function" then
            return false, "AddOn files are from different versions (missing " .. name
                .. "). Reinstall every Grimoire file, then restart the client."
        end
    end
    return true
end

local function CheckClass()
    local _, classFile = UnitClass("player")
    if classFile ~= "WARLOCK" then
        return false, "Grimoire is for Warlocks, so it stays off on this character."
    end
    return true
end

-- Per-character settings in GrimoireDB, repaired on load so a
-- damaged or older table can never break the AddOn.
WTF.SHARD_LIMIT_MIN = 1
WTF.SHARD_LIMIT_MAX = 60
WTF.DEFAULT_SHARD_LIMIT = 6
-- The shard counter turns red at or below this. Two by default: one
-- Soulstone, one Healthstone, and one summon take three shards.
WTF.SHARD_LOW_MIN = 0
WTF.SHARD_LOW_MAX = 10
WTF.DEFAULT_SHARD_LOW = 2

local function IsWholeNumber(value)
    return type(value) == "number" and value == math.floor(value)
end

function WTF.SanitizeShardLimit(value)
    if not IsWholeNumber(value) then
        return WTF.DEFAULT_SHARD_LIMIT
    end
    return math.max(WTF.SHARD_LIMIT_MIN, math.min(WTF.SHARD_LIMIT_MAX, value))
end

function WTF.SanitizeShardLow(value)
    if not IsWholeNumber(value) then
        return WTF.DEFAULT_SHARD_LOW
    end
    return math.max(WTF.SHARD_LOW_MIN, math.min(WTF.SHARD_LOW_MAX, value))
end

-- The Stones bar's and the shard counter's size, in percent (John,
-- 2026-11-12, from a player comment; as the control bar's Bar size).
WTF.FRAME_SCALE_MIN = 50
WTF.FRAME_SCALE_MAX = 150
WTF.FRAME_SCALE_STEP = 5
WTF.DEFAULT_FRAME_SCALE = 100

function WTF.SanitizeFrameScale(value)
    if not IsWholeNumber(value) then
        return WTF.DEFAULT_FRAME_SCALE
    end
    local stepped = math.floor(value / WTF.FRAME_SCALE_STEP + 0.5) * WTF.FRAME_SCALE_STEP
    return math.max(WTF.FRAME_SCALE_MIN, math.min(WTF.FRAME_SCALE_MAX, stepped))
end

local function SanitizePosition(position)
    if type(position) ~= "table" or type(position.point) ~= "string"
        or type(position.relativePoint) ~= "string"
        or type(position.x) ~= "number" or type(position.y) ~= "number" then
        return nil
    end
    return {point = position.point, relativePoint = position.relativePoint,
        x = position.x, y = position.y}
end

-- Tracker and nameplate slots, in display order, with default colors as the
-- Settings color swatch stores them (AARRGGBB), and whether each is a DoT to
-- keep up (crowd control is not). Every slot shows as a nameplate dot by
-- default (author, 1.2.0).
WTF.DOT_SLOTS = {
    {key = "curse", label = "Curse", color = "ff9e40d9", dot = true},
    {key = "bane", label = "Bane", color = "ffe62626", dot = true},
    {key = "corruption", label = "Corruption", color = "ffffffff", dot = true},
    {key = "immolate", label = "Immolate", color = "ffff8019", dot = true},
    {key = "siphon", label = "Siphon Life", color = "ff4dd94d", dot = true},
    {key = "control", label = "Fear and control", color = "ffffd91a", dot = false},
}

-- The DoT order (author-approved, player request: configurable, with the
-- rotation order above as the default): every slot key once. Unknown or
-- doubled keys are dropped and missing ones added in the default order.
function WTF.SanitizeDotOrder(value)
    local valid, seen, order = {}, {}, {}
    for _, slot in ipairs(WTF.DOT_SLOTS) do
        valid[slot.key] = true
    end
    if type(value) == "table" then
        for _, key in ipairs(value) do
            if valid[key] and not seen[key] then
                seen[key] = true
                order[#order + 1] = key
            end
        end
    end
    for _, slot in ipairs(WTF.DOT_SLOTS) do
        if not seen[slot.key] then
            order[#order + 1] = slot.key
        end
    end
    return order
end

-- WTF.DOT_SLOTS in the saved order.
function WTF.OrderedDotSlots()
    local byKey, slots = {}, {}
    for _, slot in ipairs(WTF.DOT_SLOTS) do
        byKey[slot.key] = slot
    end
    for _, key in ipairs(WTF.db.tracker.order) do
        slots[#slots + 1] = byKey[key]
    end
    return slots
end

-- Defaults that changed (author-approved): once, a slot still on its old
-- default moves to the new one; a color the user picked stays, also later.
local OLD_DEFAULT_COLORS = {curse = "ff4d8cff", corruption = "ff9e40d9"}
local TRACKER_LAYOUT_VERSION = 2
local COLORS_VERSION = 2

function WTF.SanitizeColor(value, default)
    if type(value) == "string" and value:match("^%x%x%x%x%x%x%x%x$") then
        return value:lower()
    end
    return default
end

-- A saved AARRGGBB color as r, g, b from 0 to 1 (its alpha is not used).
local function HexColor(hex)
    return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
end

function WTF.SlotColor(key)
    return HexColor(WTF.db.tracker.colors[key])
end

-- DoT tracker panel colors (author-approved, player request): each colors its
-- panel's outline or row border and its health fill. Defaults are the colors
-- before 1.2.0: the warlock class color, red, and the others' dark grey.
WTF.TRACKER_PANEL_COLORS = {
    {key = "target", label = "Target panel color", color = "ff8787ed"},
    {key = "focus", label = "Focus panel color", color = "ffe61a1a"},
    {key = "list", label = "Other mobs panel color", color = "ff545454"},
}

function WTF.PanelColor(key)
    return HexColor(WTF.db.tracker.panelColors[key])
end

WTF.PLATE_DOTS_OFFSET_MIN = 0
WTF.PLATE_DOTS_OFFSET_MAX = 120
-- Clears the name and EllesmereUI's debuff icons above it (author-tested in client:
-- 4 covered the name, 40 the icons, 50 cleared both).
WTF.DEFAULT_PLATE_DOTS_OFFSET = 50

function WTF.SanitizePlateDotsOffset(value)
    if not IsWholeNumber(value) then
        return WTF.DEFAULT_PLATE_DOTS_OFFSET
    end
    return math.max(WTF.PLATE_DOTS_OFFSET_MIN, math.min(WTF.PLATE_DOTS_OFFSET_MAX, value))
end

-- A whole number within min and max, else the default.
function WTF.SanitizeWhole(value, minValue, maxValue, default)
    if not IsWholeNumber(value) then
        return default
    end
    return math.max(minValue, math.min(maxValue, value))
end

-- DoT tracker panel opacity, per panel (author-approved: its own setting for
-- the target, focus, and other-mobs panels), in percent; 100 is today's look.
WTF.TRACKER_PANELS = {
    {key = "target", heading = "Target", name = "target panel", label = "Target panel opacity"},
    {key = "focus", heading = "Focus", name = "focus panel", label = "Focus panel opacity"},
    {key = "list", heading = "Others", name = "other mobs' panel", label = "Other mobs panel opacity"},
}
WTF.PANEL_OPACITY_MIN = 10
WTF.PANEL_OPACITY_MAX = 100
WTF.DEFAULT_PANEL_OPACITY = 100

-- The pinned target and focus rows' solid outline, in whole pixels (John,
-- 2026-11-11, from a player asking to hide it; Dyre's Toolkit 2.8.0 draws it
-- and has the same range in TRACKER_OUTLINE). 0 draws none; 3 is the old look.
WTF.OUTLINE_WIDTH_MIN = 0
WTF.OUTLINE_WIDTH_MAX = 20
WTF.DEFAULT_OUTLINE_WIDTH = 3

-- Nameplate DoT dot opacity, in percent (author-approved: 100, today's look).
WTF.PLATE_DOTS_OPACITY_MIN = 10
WTF.PLATE_DOTS_OPACITY_MAX = 100
WTF.DEFAULT_PLATE_DOTS_OPACITY = 100

-- DoT tracker sizes per theme (author-approved, player request), saved per
-- theme; the defaults are the sizes the themes always had. Text size is a
-- percent of each font's own size. No free offsets: the name sits in one of a
-- few places, so every layout is a tested one.
WTF.TRACKER_SIZE_SPECS = {
    compact = {
        {key = "iconSize", label = "Icon size", min = 16, max = 40, step = 1, default = 20},
        {key = "nameWidth", label = "Name width", min = 60, max = 200, step = 5, default = 90,
            tooltip = "The room the name has beside the icons (name Left or Right): the row grows or shrinks with "
                .. "it. A longer name is cut with \"...\". Above or below the icons, the name spans the row."},
        {key = "textScale", label = "Text size", min = 50, max = 200, step = 5, default = 100, percent = true},
    },
    bars = {
        {key = "barWidth", label = "Bar width", min = 150, max = 500, step = 10, default = 290},
        {key = "lineHeight", label = "Line height", min = 12, max = 28, step = 1, default = 16},
        {key = "textScale", label = "Text size", min = 50, max = 200, step = 5, default = 100, percent = true},
    },
}
WTF.TRACKER_NAME_POSITIONS = {
    compact = {{key = "left", label = "Left"}, {key = "right", label = "Right"}, {key = "above", label = "Above"},
        {key = "below", label = "Below"}},
    bars = {{key = "above", label = "Above"}, {key = "below", label = "Below"}},
}

-- The DoT prediction block's look (John, 1.4.0), the same on every bar:
-- the fill, a color preset, its opacity, and a thin outline.
WTF.PREDICT_FILLS = {{key = "stripes", label = "Stripes"}, {key = "solid", label = "Solid"},
    {key = "bar", label = "Bar texture"}}
WTF.PREDICT_COLORS = {
    {key = "purple", label = "Purple", color = {0.64, 0.21, 0.93}},
    {key = "red", label = "Red", color = {1, 0.15, 0.15}},
    {key = "orange", label = "Orange", color = {1, 0.55, 0.1}},
    {key = "white", label = "White", color = {1, 1, 1}},
    {key = "green", label = "Green", color = {0.25, 0.9, 0.3}},
}
WTF.PREDICT_OUTLINES = {{key = "none", label = "None"}, {key = "solid", label = "Solid"}}
WTF.PREDICT_OPACITY_MIN = 20
WTF.PREDICT_OPACITY_MAX = 100
WTF.DEFAULT_PREDICT_OPACITY = 70
-- Where DIES goes (John, 2026-11-09), apart for the target and focus frames
-- and for nameplates: Auto is the Toolkit's choice (left of a unit frame's
-- bar, right of a nameplate's, the other side when that one is taken); X and
-- Y move it from there, in pixels, right and up positive.
WTF.DIES_PLACES = {{key = "auto", label = "Auto"}, {key = "left", label = "Left of the bar"},
    {key = "right", label = "Right of the bar"}, {key = "center", label = "Center of the bar"},
    {key = "above", label = "Above the bar"}, {key = "below", label = "Below the bar"},
    {key = "inside", label = "Inside the bar's right end"}}
WTF.DIES_OFFSET_MIN = -100
WTF.DIES_OFFSET_MAX = 100

-- A saved key that is one of the choices, else the first or the default.
function WTF.SanitizeChoice(value, choices, default)
    for _, choice in ipairs(choices) do
        if value == choice.key then
            return value
        end
    end
    return default or choices[1].key
end

-- The tracker's health text choices; None by default.
WTF.TRACKER_HEALTH_TEXTS = {{key = "none", label = "None"}, {key = "number", label = "Number"},
    {key = "percent", label = "Percent"}, {key = "both", label = "Number and Percent"}}

function WTF.SanitizeHealthText(value)
    for _, choice in ipairs(WTF.TRACKER_HEALTH_TEXTS) do
        if value == choice.key then
            return value
        end
    end
    return "none"
end

function WTF.SanitizeTrackerSizes(theme, saved)
    saved = type(saved) == "table" and saved or {}
    local sizes = {}
    for _, spec in ipairs(WTF.TRACKER_SIZE_SPECS[theme]) do
        sizes[spec.key] = WTF.SanitizeWhole(saved[spec.key], spec.min, spec.max, spec.default)
    end
    local positions = WTF.TRACKER_NAME_POSITIONS[theme]
    sizes.namePosition = positions[1].key
    for _, position in ipairs(positions) do
        if saved.namePosition == position.key then
            sizes.namePosition = position.key
        end
    end
    return sizes
end

function WTF.SanitizeDB(db)
    if type(db) ~= "table" then
        db = {}
    end
    local shards = type(db.shards) == "table" and db.shards or {}
    db.shards = {
        enabled = shards.enabled ~= false,
        autoLimit = shards.autoLimit ~= false,
        limit = WTF.SanitizeShardLimit(shards.limit),
        -- Grimoire: the chat line for each deleted shard is off by default.
        report = shards.report == true,
        counter = shards.counter ~= false,
        counterLow = WTF.SanitizeShardLow(shards.counterLow),
        counterPosition = SanitizePosition(shards.counterPosition),
        counterScale = WTF.SanitizeFrameScale(shards.counterScale),
    }
    local stones = type(db.stones) == "table" and db.stones or {}
    local soulstone = type(stones.soulstone) == "table" and stones.soulstone or nil
    db.stones = {
        enabled = stones.enabled ~= false,
        shown = stones.shown ~= false,
        position = SanitizePosition(stones.position),
        scale = WTF.SanitizeFrameScale(stones.scale),
        macros = stones.macros ~= false,
        remindSoulstone = stones.remindSoulstone ~= false,
        remindHealthstone = stones.remindHealthstone ~= false,
        soulstone = soulstone and type(soulstone.name) == "string" and type(soulstone.ends) == "number"
            and {name = soulstone.name, ends = soulstone.ends} or nil,
    }
    local tracker = type(db.tracker) == "table" and db.tracker or {}
    db.tracker = {
        enabled = tracker.enabled ~= false,
        -- Where the one tracker frame was: sections not yet dragged stack there.
        position = SanitizePosition(tracker.position),
        sections = {},
        -- Bars by default (author-approved).
        theme = tracker.theme == "compact" and "compact" or "bars",
        plateDots = tracker.plateDots == true,
        plateDotsOffset = WTF.SanitizePlateDotsOffset(tracker.plateDotsOffset),
        plateDotsOpacity = WTF.SanitizeWhole(tracker.plateDotsOpacity, WTF.PLATE_DOTS_OPACITY_MIN,
            WTF.PLATE_DOTS_OPACITY_MAX, WTF.DEFAULT_PLATE_DOTS_OPACITY),
        outlineWidth = WTF.SanitizeWhole(tracker.outlineWidth, WTF.OUTLINE_WIDTH_MIN, WTF.OUTLINE_WIDTH_MAX,
            WTF.DEFAULT_OUTLINE_WIDTH),
        sizes = {},
        panelOpacity = {},
        -- Mob health (author-approved, player request): off by default.
        health = tracker.health == true,
        healthText = WTF.SanitizeHealthText(tracker.healthText),
        colors = {},
        onPlates = {},
        colorsVersion = COLORS_VERSION,
        panelColors = {},
        order = WTF.SanitizeDotOrder(tracker.order),
        -- The smart curse (Toolkit 2.7.0): the pinned Curse slot recasts the
        -- last curse ("last", default) or the smart pick ("smart"); its letter
        -- shows unless false.
        curseMode = tracker.curseMode == "smart" and "smart" or "last",
        curseMarker = tracker.curseMarker ~= false,
    }
    for _, key in ipairs({"lastBane", "lastCurse", "lastControl"}) do
        db.tracker[key] = type(tracker[key]) == "string" and tracker[key] or nil
    end
    local sizes = type(tracker.sizes) == "table" and tracker.sizes or {}
    for theme in pairs(WTF.TRACKER_SIZE_SPECS) do
        db.tracker.sizes[theme] = WTF.SanitizeTrackerSizes(theme, sizes[theme])
    end
    -- Grimoire 0.2: Compact and smaller by default (the Bars theme took too
    -- much room). Once, a theme and sizes still on WTF's defaults move to the
    -- new ones; anything you changed stays.
    if (tracker.layoutVersion or 1) < TRACKER_LAYOUT_VERSION then
        local bars, compact = db.tracker.sizes.bars, db.tracker.sizes.compact
        if db.tracker.theme == "bars" and bars.barWidth == 290 and bars.lineHeight == 16 and bars.textScale == 100 then
            db.tracker.theme = "compact"
        end
        if compact.iconSize == 22 and compact.nameWidth == 110 and compact.textScale == 100 then
            compact.iconSize, compact.nameWidth = 20, 90
        end
    end
    db.tracker.layoutVersion = TRACKER_LAYOUT_VERSION
    local panelOpacity = type(tracker.panelOpacity) == "table" and tracker.panelOpacity or {}
    for _, panel in ipairs(WTF.TRACKER_PANELS) do
        db.tracker.panelOpacity[panel.key] = WTF.SanitizeWhole(panelOpacity[panel.key], WTF.PANEL_OPACITY_MIN,
            WTF.PANEL_OPACITY_MAX, WTF.DEFAULT_PANEL_OPACITY)
    end
    local sections = type(tracker.sections) == "table" and tracker.sections or {}
    for _, key in ipairs({"target", "focus", "list"}) do
        db.tracker.sections[key] = SanitizePosition(sections[key])
    end
    local panelColors = type(tracker.panelColors) == "table" and tracker.panelColors or {}
    for _, panel in ipairs(WTF.TRACKER_PANEL_COLORS) do
        db.tracker.panelColors[panel.key] = WTF.SanitizeColor(panelColors[panel.key], panel.color)
    end
    local colors = type(tracker.colors) == "table" and tracker.colors or {}
    local onPlates = type(tracker.onPlates) == "table" and tracker.onPlates or {}
    for _, slot in ipairs(WTF.DOT_SLOTS) do
        local color = WTF.SanitizeColor(colors[slot.key], slot.color)
        if (tracker.colorsVersion or 1) < COLORS_VERSION and color == OLD_DEFAULT_COLORS[slot.key] then
            color = slot.color
        end
        db.tracker.colors[slot.key] = color
        if type(onPlates[slot.key]) == "boolean" then
            db.tracker.onPlates[slot.key] = onPlates[slot.key]
        else
            db.tracker.onPlates[slot.key] = true
        end
    end
    -- DoT damage prediction (John, 1.4.0): on by default, where the Toolkit
    -- makes a predictor. A test build's "tracker" switch is dropped.
    local predict = type(db.predict) == "table" and db.predict or {}
    db.predict = {
        enabled = predict.enabled ~= false,
        plates = predict.plates ~= false,
        dies = predict.dies ~= false,
        fill = WTF.SanitizeChoice(predict.fill, WTF.PREDICT_FILLS),
        color = WTF.SanitizeChoice(predict.color, WTF.PREDICT_COLORS),
        opacity = WTF.SanitizeWhole(predict.opacity, WTF.PREDICT_OPACITY_MIN, WTF.PREDICT_OPACITY_MAX,
            WTF.DEFAULT_PREDICT_OPACITY),
        outline = WTF.SanitizeChoice(predict.outline, WTF.PREDICT_OUTLINES, "solid"),
        diesPlace = WTF.SanitizeChoice(predict.diesPlace, WTF.DIES_PLACES, "auto"),
        diesX = WTF.SanitizeWhole(predict.diesX, WTF.DIES_OFFSET_MIN, WTF.DIES_OFFSET_MAX, 0),
        diesY = WTF.SanitizeWhole(predict.diesY, WTF.DIES_OFFSET_MIN, WTF.DIES_OFFSET_MAX, 0),
        plateDiesPlace = WTF.SanitizeChoice(predict.plateDiesPlace, WTF.DIES_PLACES, "auto"),
        plateDiesX = WTF.SanitizeWhole(predict.plateDiesX, WTF.DIES_OFFSET_MIN, WTF.DIES_OFFSET_MAX, 0),
        plateDiesY = WTF.SanitizeWhole(predict.plateDiesY, WTF.DIES_OFFSET_MIN, WTF.DIES_OFFSET_MAX, 0),
    }
    -- One lock for every frame (author-approved, as MTF), locked by default;
    -- each frame reads its own copy, and the tracker shows its sample rows
    -- while unlocked, since it can only be dragged while it shows.
    if WTF.SanitizeControl then
        db.control = WTF.SanitizeControl(db.control, SanitizePosition)
    end
    -- Grimoire 0.2: the alert window, reminders, threat, pet, Nightfall,
    -- cooldown alerts, and the shield display (each file repairs its own).
    if WTF.SanitizeAlerts then
        db.alerts = WTF.SanitizeAlerts(db.alerts, SanitizePosition)
        db.reminders = WTF.SanitizeReminders(db.reminders, SanitizePosition)
        db.threat = WTF.SanitizeThreat(db.threat)
        db.pet = WTF.SanitizePet(db.pet)
        db.procs = WTF.SanitizeProcs(db.procs, SanitizePosition)
        db.cooldowns = WTF.SanitizeCooldowns(db.cooldowns)
        db.shield = WTF.ShieldDisplay.Sanitize(db.shield)
    end
    db.locked = db.locked ~= false
    db.grid = db.grid ~= false
    db.stones.locked = db.locked
    db.tracker.locked = db.locked
    if db.shield then
        db.shield.locked = db.locked
    end
    db.tracker.placeholders = not db.locked
    db.shards.counterLocked = db.locked
    return db
end

-- Another AddOn can register the same slash command; the last one loaded wins.
-- Returns the other command key, or nil when /grim is ours alone.
local function FindSlashConflict()
    for key in pairs(SlashCmdList) do
        if key ~= SLASH_KEY then
            for index = 1, MAX_SLASH_ALIASES do
                local alias = _G["SLASH_" .. key .. index]
                if type(alias) == "string" and alias:lower() == PRIMARY_SLASH then
                    return key
                end
            end
        end
    end
end

-- Hardware input. The client lets AddOns delete or move items only during a
-- key press or click, so such work waits for the next one. Core hooks every
-- key press and every click on the game world, as RestedXP does for its junk
-- deletion; the keyboard frame passes every key on to the game and is enabled
-- only after the client confirms that.
local inputHandlers, nextInput = {}, {}

function WTF.AddInputHandler(handler)
    inputHandlers[#inputHandlers + 1] = handler
end

-- Runs once, at the next key press or click.
function WTF.RunOnNextInput(action)
    nextInput[#nextInput + 1] = action
end

local function OnInput()
    for _, handler in ipairs(inputHandlers) do
        handler()
    end
    if #nextInput > 0 then
        local actions = nextInput
        nextInput = {}
        for _, action in ipairs(actions) do
            action()
        end
    end
end

local function InstallInputHooks()
    local keys = CreateFrame("Frame", nil, UIParent)
    if type(keys.SetPropagateKeyboardInput) == "function"
        and type(keys.GetPropagateKeyboardInput) == "function" then
        keys:SetPropagateKeyboardInput(true)
        if keys:GetPropagateKeyboardInput() then
            keys:SetScript("OnKeyDown", OnInput)
            keys:EnableKeyboard(true)
            -- For /grim debug_stones: whether a key press can run waiting work.
            WTF.keyInputHooked = true
        end
    end
    WorldFrame:HookScript("OnMouseDown", OnInput)
end

-- While unlocked, a frame shows a gold outline and a hint (author-approved).
-- A plain child, so it can show and hide also in combat.
function WTF.CreateMover(frame)
    local mover = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    -- On its frame's strata, so the outline is never under what covers it.
    mover:SetFrameStrata(frame:GetFrameStrata())
    mover:SetPoint("TOPLEFT", -4, 4)
    mover:SetPoint("BOTTOMRIGHT", 4, -4)
    mover:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14})
    mover:SetBackdropBorderColor(1, 0.82, 0)
    mover.hint = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mover.hint:SetPoint("BOTTOM", mover, "TOP", 0, 2)
    mover.hint:SetText("Drag to move. /grim lock when done")
    mover:SetShown(not WTF.db.locked)
    return mover
end

-- While unlocked, an alignment grid over the screen (author-approved, as
-- MTF's): faint lines every GRID_SPACING from the center out, and the center
-- lines in red, so frames line up with the middle of the screen. Under every
-- frame, it takes no mouse. Rebuilt when the screen size or UI scale changes.
local GRID_SPACING = 32
local GRID_LINE = {1, 1, 1, 0.12}
local GRID_CENTER = {1, 0.2, 0.2, 0.7}
local grid

local function GridLine(vertical, offset, color, thickness)
    local line = grid:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(color[1], color[2], color[3], color[4])
    if vertical then
        line:SetPoint("TOP", grid, "TOP", offset, 0)
        line:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
        line:SetWidth(thickness)
    else
        line:SetPoint("LEFT", grid, "LEFT", 0, offset)
        line:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
        line:SetHeight(thickness)
    end
    grid.lines[#grid.lines + 1] = line
end

local function BuildGrid()
    for _, line in ipairs(grid.lines) do
        line:Hide()
    end
    grid.lines = {}
    local halfWidth, halfHeight = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
    for step = 1, math.floor(halfWidth / GRID_SPACING) do
        GridLine(true, step * GRID_SPACING, GRID_LINE, 1)
        GridLine(true, -step * GRID_SPACING, GRID_LINE, 1)
    end
    for step = 1, math.floor(halfHeight / GRID_SPACING) do
        GridLine(false, step * GRID_SPACING, GRID_LINE, 1)
        GridLine(false, -step * GRID_SPACING, GRID_LINE, 1)
    end
    GridLine(true, 0, GRID_CENTER, 2)
    GridLine(false, 0, GRID_CENTER, 2)
    grid.built = true
end

function WTF.RefreshGrid()
    local wanted = not WTF.db.locked and WTF.db.grid
    if not grid then
        if not wanted then
            return
        end
        grid = CreateFrame("Frame", nil, UIParent)
        grid:SetAllPoints(UIParent)
        grid:SetFrameStrata("BACKGROUND")
        grid:EnableMouse(false)
        grid.lines = {}
        grid:SetScript("OnEvent", function() grid.built = false; WTF.RefreshGrid() end)
        grid:RegisterEvent("DISPLAY_SIZE_CHANGED")
        grid:RegisterEvent("UI_SCALE_CHANGED")
    end
    if wanted and not grid.built then
        BuildGrid()
    end
    grid:SetShown(wanted)
    WTF.grid = grid
end

-- /grim unlock and /grim lock, and the main page's "Unlock frames to move them":
-- every movable frame together (author-approved, as MTF does).
local function SetLockFlags(locked)
    WTF.db.locked = locked
    WTF.db.stones.locked = locked
    WTF.db.tracker.locked = locked
    WTF.db.tracker.placeholders = not locked
    WTF.db.shards.counterLocked = locked
    if WTF.db.shield then
        WTF.db.shield.locked = locked
    end
end

function WTF.SetFramesLocked(locked, quiet)
    SetLockFlags(locked)
    WTF.RefreshTracker()
    WTF.RefreshStonesMover()
    WTF.RefreshShardCounter()
    WTF.RefreshControl()
    WTF.RefreshAlerts()
    WTF.RefreshReminders()
    WTF.RefreshProcs()
    WTF.ShieldDisplay.Refresh()
    WTF.RefreshGrid()
    if quiet then
        return
    end
    if locked then
        WTF.Report("All Grimoire frames locked.")
    else
        WTF.Report("All Grimoire frames unlocked: drag them where you want (Shift-drag moves a snapped group), "
            .. "then type /grim lock.")
    end
end

function WTF.ReportShieldDebug()
    WTF.ShieldDisplay.ReportDebug(WTF.Report)
end

function WTF.Unlock()
    WTF.SetFramesLocked(false)
end

function WTF.Lock()
    WTF.SetFramesLocked(true)
end

-- The engines (Engine\, Dyre's Toolkit 2.9.2's): the DoT tracker, the
-- nameplate dots, the prediction, and the Control bar with its macros. WTF's
-- modules call them as WTF.shared, as they called the Toolkit. Every function
-- is checked, so a mixed install of old and new files stays off with one
-- line instead of failing later.
local SHARED_FUNCTIONS = {
    "AuraEngineKind", "CreateAuraContainer",
    "ReadGUID", "ReadName", "IsDead", "LearnPlate", "LearnPlates", "ForgetPlate", "KnownPlate", "PlateGUID",
    "FindUnit", "LockCast", "FocusWorks", "OnFocusWorks", "LearnFocusWorks", "NoteFocusWorks", "ResetFocusWorks",
    "FindPlateBar", "FindUnitBar", "UseBar", "PrepareBar", "DrawPrediction", "HidePrediction", "MoveDies",
    "SpellName", "IndexSpells", "KnowsAny", "PetKnows", "OutOfCombat", "CreateMacroKeeper", "FocusCastMacro",
    "MarkerCode", "FormatAnnouncement", "CreateAnnouncer", "ClaimOwner", "SetOwnerEnabled", "IsOwner",
    "CreateControlTracker", "CreateDotTracker", "CreatePlateDots", "CreateDotPredictor",
}
local SHARED_MISSING = "Engine files are missing or from another version, so the DoT tracker, the nameplate "
    .. "DoT dots, the Control bar, and DoT damage prediction stay off. Reinstall every Grimoire file."

function WTF.SharedToolkit()
    local toolkit = type(WTF.engine) == "table" and WTF.engine.toolkit
    if type(toolkit) ~= "table" then
        return nil
    end
    for _, name in ipairs(SHARED_FUNCTIONS) do
        if type(toolkit[name]) ~= "function" then
            return nil
        end
    end
    return toolkit
end

local function UseShared()
    local shared = WTF.SharedToolkit()
    WTF.shared = shared
    if not shared then
        WTF.Report(SHARED_MISSING)
        return
    end
    WTF.AuraEngineKind = shared.AuraEngineKind
    WTF.AURA_ENGINE_MISSING = shared.AURA_ENGINE_MISSING
    -- For the shield display (Shield.lua reads them from the namespace).
    WTF.CreateAuraContainer = shared.CreateAuraContainer
end

-- /grim reset: the Stones bar, the DoT tracker, the shard counter, and the Control bar back to their default places.
function WTF.ResetPositions()
    WTF.ResetShardCounterPosition()
    WTF.ResetStonesPosition()
    WTF.ResetTrackerPosition()
    WTF.ResetControlPosition()
    WTF.ResetAlertsPosition()
    WTF.ResetRemindersPosition()
    WTF.ResetProcsPosition()
    WTF.ShieldDisplay.ResetPosition()
    if InCombatLockdown() then
        WTF.Report("Grimoire frames move back to their default places after combat.")
    end
end

SLASH_GRIMOIRE1 = PRIMARY_SLASH
SLASH_GRIMOIRE2 = BACKUP_SLASH
SlashCmdList[SLASH_KEY] = WTF.HandleCommand

-- Account-wide: GrimoireAccountDB.engine is the engines' one saved table
-- (Engine\Shim.lua): focusWorks (only true survives), the prediction's learned
-- ticks (DotPredict.lua repairs them once a session), and ticksImported.
local function LoadAccountDB(saved)
    saved = type(saved) == "table" and saved or {}
    local engine = type(saved.engine) == "table" and saved.engine or {}
    engine.focusWorks = engine.focusWorks == true or nil
    if type(engine.ticks) ~= "table" then
        engine.ticks = {}
    end
    if type(engine.ticksImported) ~= "table" then
        engine.ticksImported = nil
    end
    return {engine = engine}
end

local function LoadDB()
    GrimoireAccountDB = LoadAccountDB(GrimoireAccountDB)
    WTF.accountDB = GrimoireAccountDB
    WTF.engine.db = GrimoireAccountDB.engine
    GrimoireDB = WTF.SanitizeDB(GrimoireDB)
    WTF.db = GrimoireDB
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, loadedName)
    if event == "ADDON_LOADED" then
        if loadedName == addonName then
            self:UnregisterEvent("ADDON_LOADED")
            LoadDB()
        end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    if not WTF.db then
        LoadDB()
    end
    local available, message = CheckInstalledFiles()
    if available then
        available, message = CheckClass()
    end
    if available then
        available, message = WTF.CheckShardCapabilities()
    end
    WTF.available = available
    ReportLoaded(available)
    local conflict = FindSlashConflict()
    if conflict then
        WTF.Report("Another AddOn (" .. conflict .. ") also uses " .. PRIMARY_SLASH
            .. ". Use " .. BACKUP_SLASH .. " instead.")
    end
    if not available then
        WTF.Report(message)
        return
    end
    -- Called directly rather than from each file's own PLAYER_LOGIN handler,
    -- so startup never depends on event handler order.
    UseShared()
    InstallInputHooks()
    -- The alert window first: the other modules write to it.
    WTF.InitializeAlerts()
    WTF.InitializeShards()
    WTF.InitializeStones()
    if WTF.shared then
        -- The predictor first: the DoT tracker's rows draw its damage.
        WTF.InitializePredict()
        WTF.InitializeTracker()
        WTF.InitializeControl()
        WTF.InitializePlateDots()
        WTF.InitializeReminders()
        WTF.InitializeProcs()
    end
    WTF.InitializeThreat()
    WTF.InitializePet()
    WTF.InitializeCooldowns()
    WTF.ShieldDisplay.Initialize({settings = function() return WTF.db.shield end, report = WTF.Report,
        unlockHint = "Drag to move. /grim lock when done", missingSounds = function() end})
    WTF.InitializeProbe()
    WTF.InitializeOptions()
    WTF.RefreshGrid()
end)
