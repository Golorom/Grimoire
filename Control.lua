local _, WTF = ...

-- Control bar (author-approved, after MTF's Polymorph bar): a block per mob you
-- Fear or Banish, in WTF's Bars format, the Focus box above it for your
-- focus's Fear, Fear timers under nameplates, the "! Fear", "! Banish", and
-- "! Seduction" macros. Grimoire: no cast announcements and no raid marker in
-- the macros (markerFor is always none). Since 1.5.0 the engine is
-- Dyre's Toolkit's (Control.lua's CreateControlTracker, 2.5.0, moved from
-- here; its header holds the rules). WTF keeps its settings (db.control and
-- the announce texts), its frame names, the bar's place and mover, its
-- Options page, and its tooltips; it claims the Warlock's control bar,
-- macros, and announcements at priority 10, so Dyre's Debuff Tracker (5)
-- steps aside for them.

local CONTROL_PRIORITY = 10
local DEFAULT_POINT = {"CENTER", "CENTER", -260, -60}
local SAMPLES = {"Fear (sample)", "Banish (sample)"}
local FOCUS_RED = {0.9, 0.1, 0.1}
-- The engine's own row border (Engine\Control.lua IDLE_BORDER), for Dyre's style.
local DYRE_BORDER = {0.45, 0.35, 0.2}
-- The engine's default look (WTF's Bars theme): the bar's size for its mover.
local ROW_WIDTH, ROW_HEIGHT, ROW_GAP, ROWS = 200, 40, 4, 5
local MARKERS_VERSION = 2
WTF.CONTROL_SCALE_MIN = 50
WTF.CONTROL_SCALE_MAX = 150
WTF.CONTROL_SCALE_STEP = 5
WTF.DEFAULT_CONTROL_SCALE = 100

-- The settings page and the sanitizer read the spells at load, from the
-- engines' tables (Engine\, loaded first by the TOC).
local toolkit = WTF.engine and WTF.engine.toolkit
local classData = type(toolkit) == "table" and type(toolkit.ClassData) == "table" and toolkit.ClassData.WARLOCK
WTF.CONTROL_SPELLS = classData and classData.control or {}
WTF.RAID_MARKERS = type(toolkit) == "table" and toolkit.RAID_MARKERS or {{index = 0, label = "None"}}

local control = {available = false}
local anchor

local function IsWholeNumber(value)
    return type(value) == "number" and value == math.floor(value)
end

function WTF.SanitizeControlScale(value)
    if not IsWholeNumber(value) then
        return WTF.DEFAULT_CONTROL_SCALE
    end
    local stepped = math.floor(value / WTF.CONTROL_SCALE_STEP + 0.5) * WTF.CONTROL_SCALE_STEP
    return math.max(WTF.CONTROL_SCALE_MIN, math.min(WTF.CONTROL_SCALE_MAX, stepped))
end

-- The saved control settings, repaired; Core calls this from SanitizeDB.
-- Saved markers of spells the Toolkit does not list (none without it) stay.
function WTF.SanitizeControl(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    -- Grimoire: no raid markers, so none are kept (markerFor is always none).
    local clean = {enabled = saved.enabled ~= false, position = sanitizePosition(saved.position),
        scale = WTF.SanitizeControlScale(saved.scale), markers = {}, markersVersion = MARKERS_VERSION,
        plateTimers = saved.plateTimers ~= false, macros = saved.macros ~= false,
        style = WTF.SanitizeChoice(saved.style, WTF.FRAME_STYLES, "dyre")}
    return clean
end

-- Whether this client's focus has been seen to work: the Toolkit's one flag
-- for every Dyre's AddOn (Units.lua), else WTF's own from before 1.4.1.
function WTF.FocusWorks()
    if WTF.shared then
        return WTF.shared.FocusWorks()
    end
    return false
end

-- A macro's text for one of ClassData's macro defs (the Toolkit's
-- FocusCastMacro with WTF's marker settings).
function WTF.ControlMacroBody(def)
    if not control.available then
        return nil
    end
    return control.tracker:MacroBody(def)
end

-- Out of combat only (the Toolkit waits for it); turning the macros off
-- deletes them.
function WTF.ApplyControlMacros()
    if control.available then
        control.tracker:ApplyMacros()
    end
    -- "! Curse" (Tracker.lua) follows the same switch.
    WTF.ApplyCurseMacro()
end

-- Display ----------------------------------------------------------------------

local function Place()
    local position = WTF.db.control.position
    anchor:ClearAllPoints()
    if position then
        anchor:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        anchor:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[2], DEFAULT_POINT[3], DEFAULT_POINT[4])
    end
end

-- The bar holds the secure click slots and the Focus box, so it scales and
-- shows only out of combat; its scale reaches the Focus box once, and the
-- rows (plain frames on UIParent) take the same scale from the engine.
local function ApplyAnchor()
    local tracker = control.tracker
    local settings = WTF.db.control
    local scale = settings.scale / 100
    anchor:SetScale(scale)
    if tracker.scale ~= scale then
        tracker:SetScale(scale)
    end
    anchor:SetShown(settings.enabled and tracker:IsOwner("control") and (tracker:KnowsAny() or not WTF.db.locked))
end

local function OnChange()
    WTF.shared.OutOfCombat(control, ApplyAnchor)
end

local function ShowTooltip(holder)
    GameTooltip:SetOwner(holder, "ANCHOR_TOP")
    if holder.spellName then
        GameTooltip:SetText("Click: " .. holder.spellName .. " your focus again.", 1, 1, 1)
        GameTooltip:AddLine("No marker and no target change. With no focus it does nothing.", 0.7, 0.7, 0.7,
            true)
    elseif WTF.FocusWorks() then
        GameTooltip:SetText("Banish your focus (\"! Banish\"), then click its row to cast it again.", 0.7, 0.7,
            0.7)
    else
        GameTooltip:SetText("Your Fears and Banishes show here with their time left.", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

function WTF.RefreshControl()
    if control.available then
        control.tracker:Refresh()
        OnChange()
    end
end

-- 0.3.5: Dyre's borders, or gold on every row and the Focus box. Plain
-- frames, so at once, also in combat.
local function ApplyStyle()
    if not control.available then
        return
    end
    local gold = WTF.db.control.style == "gold"
    local rowBorder = gold and WTF.GOLD_RIM or DYRE_BORDER
    for _, row in ipairs(control.tracker.rows or {}) do
        row:SetBackdropBorderColor(rowBorder[1], rowBorder[2], rowBorder[3])
    end
    local box = control.tracker.focusBox
    if box and box.display then
        local color = gold and WTF.GOLD_RIM or control.focusColor or FOCUS_RED
        box.display:SetBackdropBorderColor(color[1], color[2], color[3])
    end
end

function WTF.SetControlStyle(style)
    WTF.db.control.style = WTF.SanitizeChoice(style, WTF.FRAME_STYLES, "dyre")
    ApplyStyle()
end

function WTF.SetControlScale(percent)
    WTF.db.control.scale = WTF.SanitizeControlScale(percent)
    WTF.RefreshControl()
end

-- 0.3.5: the bar's look in its Edit Mode dialog (the size was on the page).
function WTF.AddControlEditModeSettings(frame)
    WTF.AddEditModeSettings(frame, function(kinds)
        local styles = {}
        for _, choice in ipairs(WTF.FRAME_STYLES) do
            styles[#styles + 1] = {text = choice.label, value = choice.key}
        end
        return {
            {kind = kinds.Slider, name = "Size", default = WTF.DEFAULT_CONTROL_SCALE,
                minValue = WTF.CONTROL_SCALE_MIN, maxValue = WTF.CONTROL_SCALE_MAX, valueStep = WTF.CONTROL_SCALE_STEP,
                get = function() return WTF.db.control.scale end,
                set = function(_, value) WTF.SetControlScale(value) end,
                desc = "In percent. A change in combat applies when combat ends."},
            {kind = kinds.Dropdown, name = "Style", default = "dyre", values = styles,
                get = function() return WTF.db.control.style end,
                set = function(_, value) WTF.SetControlStyle(value) end,
                desc = "Dyre's: a dark gold border, red on the Focus box. Gold rim: a gold border on every row "
                    .. "and the Focus box, as the game's own frames have."},
        }
    end)
end

function WTF.ResetControlPosition()
    WTF.db.control.position = nil
    if control.available then
        WTF.shared.OutOfCombat(Place, Place)
    end
end

function WTF.InitializeControl()
    if not WTF.shared.AuraEngineKind() then
        WTF.Report("The control bar stays off: this client lacks " .. WTF.AURA_ENGINE_MISSING .. ".")
        return
    end
    anchor = CreateFrame("Frame", "GrimoireControl", UIParent)
    anchor:SetSize(ROW_WIDTH, ROWS * (ROW_HEIGHT + ROW_GAP) - ROW_GAP)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:EnableMouse(false)
    WTF.RegisterMovable(anchor, function(position) WTF.db.control.position = position end,
        {name = "Grimoire Control bar", default = WTF.EditModeDefault(DEFAULT_POINT)})
    WTF.AddControlEditModeSettings(anchor)
    Place()
    local color = FOCUS_RED
    if WTF.db.tracker and WTF.db.tracker.panelColors then
        color = {WTF.PanelColor("focus")}
    end
    local tracker, missing = WTF.shared.CreateControlTracker({
        addon = "Grimoire",
        priority = CONTROL_PRIORITY,
        class = "WARLOCK",
        store = WTF.db.control,
        names = {row = "GrimoireControlRow", click = "GrimoireControlClick",
            focus = "GrimoireControlFocus"},
        parent = anchor,
        rows = ROWS,
        locked = function() return WTF.db.locked ~= false end,
        samples = SAMPLES,
        focusBox = {key = "fear", color = color},
        -- No raid marker in "! Banish" and the others (no /tm line).
        markerFor = function() return 0 end,
        keeper = {warn = WTF.Warn},
        tooltip = ShowTooltip,
        onChange = function()
            if control.available then
                OnChange()
            end
        end,
    })
    if not tracker then
        WTF.Report("The control bar stays off: this client lacks " .. tostring(missing) .. ".")
        return
    end
    control.tracker = tracker
    control.focusColor = color
    WTF.controlRows = tracker.rows
    WTF.controlFocusBox = tracker.focusBox
    WTF.fearPlateTimers = tracker.plateTimers
    control.available = true
    ApplyStyle()
    WTF.RefreshControl()
end

-- /grim reset_focus: forget that this client's focus works, so the macros fall
-- back again until a focus is seen (out of combat; in combat, after it).
local RESET_FALLBACK = "Grimoire's macros try your focus, then the mob under the mouse, then your target, "
    .. "until a focus is seen to work."

function WTF.ResetFocusWorks()
    if WTF.shared then
        WTF.shared.ResetFocusWorks()
    end
    WTF.Report("Focus check reset. " .. RESET_FALLBACK)
end

-- /grim debug_control: the IDs, each row's mob and click, and the last cast.
function WTF.ReportControlDebug()
    WTF.Report(string.format("debug_control available=%s focusWorks=%s", tostring(control.available),
        tostring(WTF.FocusWorks())))
    if not control.available then
        return
    end
    for _, line in ipairs(control.tracker:DebugLines()) do
        WTF.Report("debug_control " .. line)
    end
    -- For the Seduction macro: your demon's family and whether it knows Seduction.
    local family = type(UnitCreatureFamily) == "function" and UnitCreatureFamily("pet")
    WTF.Report(string.format("debug_control pet=%s seduction=%s", tostring(family),
        tostring(WTF.shared.PetKnows(6358))))
end
