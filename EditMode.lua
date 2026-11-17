local _, WTF = ...

-- Grimoire's frames in the game's Edit Mode (0.3.0). Replaces Layout.lua,
-- WTF's own unlock with magnetic snapping.
--
-- LibEditMode (p3lim; Libs\LibEditMode, embedded unmodified under its own
-- license, in Grimoire's namespace so no other AddOn's copy is involved)
-- adds each frame to Edit Mode. There it shows with its name, drags, takes
-- exact coordinates and arrow-key nudges, and has Reset Position. LibEditMode
-- does not snap, so Grimoire does (0.3.1): a dropped frame snaps as the
-- game's own do, while Edit Mode's "Snap to Elements" is on.
--
-- Entering Edit Mode shows every frame's sample, as the old unlock did, and
-- leaving it hides them again (Core's SetFramesLocked). A frame has one place
-- for every Edit Mode layout. Places save as before, {point, relativePoint,
-- x, y} against UIParent, so places from 0.2 carry over.

local editMode = {saves = {}, order = {}, names = {}, defaults = {}, editing = false}
WTF.editMode = editMode

local function Lib()
    local lib = WTF.LibEditMode
    if type(lib) == "table" and type(lib.AddFrame) == "function" and type(lib.RegisterCallback) == "function"
        and type(C_EditMode) == "table" then
        return lib
    end
end

function WTF.EditModeAvailable()
    return Lib() ~= nil
end

-- Edit Mode's highlight sits over the frame and every child, so a click in
-- Edit Mode selects the frame and never presses one of its buttons.
local function RaiseHighlights(lib)
    local selections = lib.frameSelections
    if type(selections) ~= "table" then
        return
    end
    for _, frame in ipairs(editMode.order) do
        local selection = selections[frame]
        if selection then
            selection:SetFrameStrata(frame:GetFrameStrata())
            selection:SetFrameLevel(math.min(frame:GetFrameLevel() + 100, 10000))
        end
    end
end

local function Moved(frame, _, point, x, y)
    local save = editMode.saves[frame]
    if save and type(point) == "string" and type(x) == "number" and type(y) == "number" then
        save({point = point, relativePoint = point, x = x, y = y})
    end
end

local function SetEditing(editing)
    editMode.editing = editing
    if editing then
        RaiseHighlights(Lib())
    end
    if WTF.available and WTF.SetFramesLocked then
        WTF.SetFramesLocked(not editing)
    end
end

-- Snapping (0.3.1) ---------------------------------------------------------
-- On a drop, each edge and the center line of the frame look for the nearest
-- line within SNAP_RANGE: the grid's lines while the grid shows, the screen's
-- edges and center, and the edges and center lines of other frames beside it
-- (the game's Edit Mode frames and Grimoire's). Then LibEditMode saves the
-- snapped place as usual.
local SNAP_RANGE = 10

-- left, right, top, bottom in UIParent's units.
local function Bounds(frame)
    if type(frame) ~= "table" or type(frame.GetCenter) ~= "function" then
        return
    end
    local x, y = frame:GetCenter()
    local width, height = frame:GetWidth(), frame:GetHeight()
    if type(x) ~= "number" or type(y) ~= "number" or type(width) ~= "number" or type(height) ~= "number"
        or WTF.IsSecret(x) or WTF.IsSecret(width) then
        return
    end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    x, y, width, height = x * ratio, y * ratio, width * ratio, height * ratio
    return x - width / 2, x + width / 2, y + height / 2, y - height / 2
end

local function Manager()
    local manager = rawget(_G, "EditModeManagerFrame")
    return type(manager) == "table" and manager or nil
end

-- Edit Mode's "Snap to Elements"; on when the client does not say.
function WTF.EditModeSnapEnabled()
    local manager = Manager()
    if manager and type(manager.IsSnapEnabled) == "function" then
        local ok, enabled = pcall(manager.IsSnapEnabled, manager)
        if ok then
            return enabled ~= false
        end
    end
    return true
end

-- The grid's center and spacing in UIParent's units, while it shows.
local function Grid()
    local manager = Manager()
    local grid = manager and manager.Grid
    if type(grid) ~= "table" or type(grid.IsShown) ~= "function" or not grid:IsShown() then
        return
    end
    local spacing = grid.gridSpacing
    if type(spacing) ~= "number" or spacing <= 0 then
        return
    end
    local left, right, top, bottom = Bounds(grid)
    if not left then
        return
    end
    local ratio = grid:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return (left + right) / 2, (top + bottom) / 2, spacing * ratio
end

-- The other frames a frame can snap to: the game's Edit Mode frames and
-- Grimoire's, those shown.
local function Others(frame)
    local others = {}
    local manager = Manager()
    local systems = manager and manager.registeredSystemFrames
    if type(systems) == "table" then
        for _, system in ipairs(systems) do
            if type(system) == "table" and system ~= frame and type(system.IsShown) == "function"
                and system:IsShown() then
                others[#others + 1] = system
            end
        end
    end
    for _, other in ipairs(editMode.order) do
        if other ~= frame and other:IsShown() then
            others[#others + 1] = other
        end
    end
    return others
end

function WTF.SnapFrame(frame)
    local left, right, top, bottom = Bounds(frame)
    if not left then
        return false
    end
    local centerX, centerY = (left + right) / 2, (top + bottom) / 2
    local bestX, bestY
    local function TryX(edge, line)
        local shift = line - edge
        if math.abs(shift) <= SNAP_RANGE and (not bestX or math.abs(shift) < math.abs(bestX)) then
            bestX = shift
        end
    end
    local function TryY(edge, line)
        local shift = line - edge
        if math.abs(shift) <= SNAP_RANGE and (not bestY or math.abs(shift) < math.abs(bestY)) then
            bestY = shift
        end
    end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    for _, line in ipairs({0, width / 2, width}) do
        TryX(left, line)
        TryX(centerX, line)
        TryX(right, line)
    end
    for _, line in ipairs({0, height / 2, height}) do
        TryY(bottom, line)
        TryY(centerY, line)
        TryY(top, line)
    end
    local gridX, gridY, spacing = Grid()
    if gridX then
        for _, edge in ipairs({left, centerX, right}) do
            TryX(edge, gridX + math.floor((edge - gridX) / spacing + 0.5) * spacing)
        end
        for _, edge in ipairs({bottom, centerY, top}) do
            TryY(edge, gridY + math.floor((edge - gridY) / spacing + 0.5) * spacing)
        end
    end
    for _, other in ipairs(Others(frame)) do
        local otherLeft, otherRight, otherTop, otherBottom = Bounds(other)
        if otherLeft then
            -- Side by side (close in height): line up left, right or centers.
            if bottom <= otherTop + SNAP_RANGE and top >= otherBottom - SNAP_RANGE then
                for _, line in ipairs({otherLeft, otherRight}) do
                    TryX(left, line)
                    TryX(right, line)
                end
                TryX(centerX, (otherLeft + otherRight) / 2)
            end
            -- One above the other (close in width): tops, bottoms or centers.
            if left <= otherRight + SNAP_RANGE and right >= otherLeft - SNAP_RANGE then
                for _, line in ipairs({otherTop, otherBottom}) do
                    TryY(top, line)
                    TryY(bottom, line)
                end
                TryY(centerY, (otherTop + otherBottom) / 2)
            end
        end
    end
    if not bestX and not bestY then
        return false
    end
    local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (left + (bestX or 0)) * ratio, (bottom + (bestY or 0)) * ratio)
    return true
end

-- Grimoire's snap runs first on a drop, then LibEditMode's own handler,
-- which reads the snapped place, shows its numbers and saves it.
local function SnapOnDrop(lib, frame)
    local selections = lib.frameSelections
    local selection = type(selections) == "table" and selections[frame]
    if not selection or selection.grimoireSnap or type(selection.GetScript) ~= "function" then
        return
    end
    local original = selection:GetScript("OnDragStop")
    if type(original) ~= "function" then
        return
    end
    selection.grimoireSnap = true
    selection:SetScript("OnDragStop", function(self, ...)
        if not InCombatLockdown() and WTF.EditModeSnapEnabled() then
            frame:StopMovingOrSizing()
            local ok, failure = pcall(WTF.SnapFrame, frame)
            if not ok then
                editMode.snapFailure = tostring(failure)
            end
        end
        return original(self, ...)
    end)
end

-- info: {name = shown in Edit Mode, default = {point, x, y} for Reset
-- Position}. Without a name, the frame's own; without a default, the center.
function WTF.RegisterMovable(frame, save, info)
    info = info or {}
    if not editMode.saves[frame] then
        editMode.order[#editMode.order + 1] = frame
    end
    editMode.saves[frame] = save
    local name = info.name or frame:GetName() or "Grimoire"
    local default = info.default or {point = "CENTER", x = 0, y = 0}
    editMode.names[frame], editMode.defaults[frame] = name, default
    local lib = Lib()
    if lib then
        lib:AddFrame(frame, Moved, default, name)
        SnapOnDrop(lib, frame)
        if editMode.editing then
            RaiseHighlights(lib)
        end
    end
end

-- Settings in a frame's Edit Mode dialog (LibEditMode's, as the game's own
-- frames have). build(kinds) returns the list, kinds being LibEditMode's
-- SettingType. Nothing happens without Edit Mode.
function WTF.AddEditModeSettings(frame, build)
    local lib = Lib()
    if not lib or type(lib.AddFrameSettings) ~= "function" or type(lib.SettingType) ~= "table" then
        return false
    end
    lib:AddFrameSettings(frame, build(lib.SettingType))
    return true
end

-- Bars of buttons (0.3.3): the Stones bar and the reminder icons share one
-- look and one set of Edit Mode settings: a row or a column, a size, the
-- space between the buttons, and the brown panel with a gold border behind.
local BAR_BACKDROP = {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = {left = 3, right = 3, top = 3, bottom = 3}}
local BAR_BROWN = {0.28, 0.16, 0.07, 0.85}
local BAR_GOLD = {1, 0.82, 0}

-- settings: {layout, spacing, background}. Secure buttons: out of combat only.
function WTF.LayoutButtonBar(bar, list, settings, size, padding)
    local vertical = settings.layout == "vertical"
    local long = padding * 2 + size * #list + settings.spacing * (#list - 1)
    local short = padding * 2 + size
    bar:SetSize(vertical and short or long, vertical and long or short)
    for index, button in ipairs(list) do
        local offset = padding + (index - 1) * (size + settings.spacing)
        button:ClearAllPoints()
        if vertical then
            button:SetPoint("TOP", bar, "TOP", 0, -offset)
        else
            button:SetPoint("LEFT", bar, "LEFT", offset, 0)
        end
    end
    if type(bar.SetBackdrop) ~= "function" then
        return
    end
    if settings.background then
        bar:SetBackdrop(BAR_BACKDROP)
        bar:SetBackdropColor(BAR_BROWN[1], BAR_BROWN[2], BAR_BROWN[3], BAR_BROWN[4])
        bar:SetBackdropBorderColor(BAR_GOLD[1], BAR_GOLD[2], BAR_GOLD[3])
    else
        bar:SetBackdrop(nil)
    end
end

-- The dialog for such a bar. options: settings() returns its saved table;
-- setLook(key, value) for layout, spacing and background; setScale(percent);
-- spacing and background: the defaults; what: what the panel is behind.
function WTF.AddButtonBarSettings(bar, options)
    local function Get(key)
        return function() return options.settings()[key] end
    end
    local function Look(key)
        return function(_, value) options.setLook(key, value) end
    end
    return WTF.AddEditModeSettings(bar, function(kinds)
        local layouts = {}
        for _, choice in ipairs(WTF.STONES_LAYOUTS) do
            layouts[#layouts + 1] = {text = choice.label, value = choice.key}
        end
        return {
            {kind = kinds.Dropdown, name = "Layout", default = "horizontal", values = layouts, get = Get("layout"),
                set = Look("layout"), desc = "A row or a column."},
            {kind = kinds.Slider, name = "Size", default = WTF.DEFAULT_FRAME_SCALE, minValue = WTF.FRAME_SCALE_MIN,
                maxValue = WTF.FRAME_SCALE_MAX, valueStep = WTF.FRAME_SCALE_STEP, get = Get("scale"),
                set = function(_, value) options.setScale(value) end, desc = "In percent."},
            {kind = kinds.Slider, name = "Button spacing", default = options.spacing,
                minValue = WTF.STONES_SPACING_MIN, maxValue = WTF.STONES_SPACING_MAX, valueStep = 1,
                get = Get("spacing"), set = Look("spacing"), desc = "The space between the buttons."},
            {kind = kinds.Checkbox, name = "Background", default = options.background, get = Get("background"),
                set = Look("background"), desc = "The brown panel with the gold border behind " .. options.what .. "."},
        }
    end)
end

-- Saved bar settings repaired: layout, spacing, background.
function WTF.SanitizeButtonBar(saved, into, spacing, background)
    into.layout = WTF.SanitizeChoice(saved.layout, WTF.STONES_LAYOUTS, "horizontal")
    into.spacing = WTF.SanitizeWhole(saved.spacing, WTF.STONES_SPACING_MIN, WTF.STONES_SPACING_MAX, spacing)
    if saved.background == nil then
        into.background = background
    else
        into.background = saved.background == true
    end
    return into
end

-- A default place given the way the modules give theirs ({"CENTER", "CENTER", x, y}).
function WTF.EditModeDefault(point)
    return {point = point[1], x = point[3], y = point[4]}
end

-- The tracker engine's drag hooks. Edit Mode does the dragging now.
function WTF.BeginDrag() end
function WTF.EndDrag() end

-- Changes a frame's scale without moving its center, and saves the place.
function WTF.ScaleKeepingCenter(frame, scale)
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = frame:GetCenter()
    x, y = x * ratio, y * ratio
    frame:SetScale(scale)
    ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    local position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = x * ratio, y = y * ratio}
    frame:ClearAllPoints()
    frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    if editMode.saves[frame] then
        editMode.saves[frame](position)
    end
end

function WTF.EditModeLines()
    local lines = {string.format("edit mode available=%s editing=%s frames=%d snap=%s%s", tostring(Lib() ~= nil),
        tostring(editMode.editing), #editMode.order, tostring(WTF.EditModeSnapEnabled()),
        editMode.snapFailure and (" failure=" .. editMode.snapFailure) or "")}
    for _, frame in ipairs(editMode.order) do
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        lines[#lines + 1] = string.format("  %s: %s %s %s %s scale %.2f shown %s", editMode.names[frame],
            tostring(point), tostring(relativePoint), x and string.format("%.1f", x) or "?",
            y and string.format("%.1f", y) or "?", frame:GetScale(), tostring(frame:IsShown()))
    end
    return lines
end

function WTF.ReportEditModeDebug()
    for _, line in ipairs(WTF.EditModeLines()) do
        WTF.Report("debug_editmode " .. line)
    end
end

local lib = Lib()
if lib then
    lib:RegisterCallback("enter", function() SetEditing(true) end)
    lib:RegisterCallback("exit", function() SetEditing(false) end)
end
