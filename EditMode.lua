local _, WTF = ...

-- Grimoire's frames in the game's Edit Mode (0.3.0). Replaces Layout.lua,
-- WTF's own unlock with magnetic snapping.
--
-- LibEditMode (p3lim; Libs\LibEditMode, embedded unmodified under its own
-- license, in Grimoire's namespace so no other AddOn's copy is involved)
-- adds each frame to Edit Mode. There it shows with its name, drags, takes
-- exact coordinates and arrow-key nudges, and has Reset Position.
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
        if editMode.editing then
            RaiseHighlights(lib)
        end
    end
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

local HELP = "Move Grimoire's frames in the game's Edit Mode: press Esc, then Edit Mode."
local NO_EDIT_MODE = "This client has no Edit Mode, so Grimoire's frames stay where they are."

-- /grim unlock and /grim lock, kept for the habit.
function WTF.ShowEditModeHelp()
    WTF.Report(Lib() and HELP or NO_EDIT_MODE)
end

function WTF.EditModeLines()
    local lines = {string.format("edit mode available=%s editing=%s frames=%d", tostring(Lib() ~= nil),
        tostring(editMode.editing), #editMode.order)}
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
