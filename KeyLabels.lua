local _, WTF = ...

-- Grimoire: the pet bar's key labels look like the other bars' labels. Edit
-- Mode's Icon Size scales a whole button, its key label too, and pet buttons
-- are smaller than action buttons, so a pet bar sized to match the other bars
-- got labels half again as big (user, 2026-11-15), and the pet template puts
-- its label in another spot than the action bars' top right corner.
--   size      each label's font size is divided by its button's scale
--             against UIParent, so it shows at the size it has at 100%.
--   place     each label takes the anchors, justification and size of a
--             standard action button's label (ActionButton1's), with offsets
--             scaled the same way, so it sits where theirs do at 100%.
-- A FontString is not protected; still, the anchors change only out of
-- combat (they cannot change in combat anyway). Turned off, the labels get
-- their own font, anchors, justification and size back.

local PET_SLOTS = 10
-- The labels to copy the place from, in order: the main bar, then the bottom
-- bars, in case a client hides the main one.
local REFERENCES = {"ActionButton1", "MultiBarBottomLeftButton1", "MultiBarBottomRightButton1"}

local saved = {}
local pendingPlace = false

function WTF.SanitizeKeyLabels(settings)
    settings = type(settings) == "table" and settings or {}
    return {petNormal = settings.petNormal ~= false}
end

local function LabelOf(name)
    local button = _G[name]
    local label = button and (button.HotKey or _G[name .. "HotKey"])
    return button, label
end

-- The pet buttons and their key labels, by the template's parentKey or the
-- named child, whichever the client has.
local function PetLabels()
    local found = {}
    for index = 1, (tonumber(NUM_PET_ACTION_SLOTS) or PET_SLOTS) do
        local button, label = LabelOf("PetActionButton" .. index)
        if label and type(label.GetFont) == "function" and type(button.GetEffectiveScale) == "function" then
            found[#found + 1] = {button = button, label = label}
        end
    end
    return found
end

local function CanPlace(label)
    for _, method in ipairs({"GetNumPoints", "GetPoint", "ClearAllPoints", "SetPoint"}) do
        if type(label[method]) ~= "function" then
            return false
        end
    end
    return true
end

local function Reference()
    for _, name in ipairs(REFERENCES) do
        local button, label = LabelOf(name)
        if label and CanPlace(label) and label:GetNumPoints() > 0 then
            return button, label
        end
    end
end

-- A label's anchors; onButton marks the ones on its own button (or on its
-- parent, which is the button), so they can move to another button.
local function Points(label, button)
    local points = {}
    for index = 1, label:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = label:GetPoint(index)
        points[#points + 1] = {point = point, relativeTo = relativeTo, relativePoint = relativePoint or point,
            x = x or 0, y = y or 0, onButton = relativeTo == nil or relativeTo == button}
    end
    return points
end

-- The client's own look, read once before any change.
local function Own(entry)
    local label = entry.label
    if saved[label] then
        return saved[label]
    end
    local font, size, flags = label:GetFont()
    if not (font and size) then
        return nil
    end
    local own = {font = font, size = size, flags = flags}
    if CanPlace(label) then
        own.points = Points(label, entry.button)
        own.justify = type(label.GetJustifyH) == "function" and label:GetJustifyH() or nil
        if type(label.GetWidth) == "function" and type(label.GetHeight) == "function" then
            own.width, own.height = label:GetWidth(), label:GetHeight()
        end
    end
    saved[label] = own
    return own
end

local function SetSize(label, width, height)
    if type(label.SetSize) == "function" and type(width) == "number" and type(height) == "number"
        and width > 0 and height > 0 then
        label:SetSize(width, height)
    end
end

local function SetJustify(label, justify)
    if justify and type(label.SetJustifyH) == "function" then
        label:SetJustifyH(justify)
    end
end

-- factor: the pet button's units per reference unit at 100%.
local function PlaceLikeReference(entry, refButton, refLabel, factor)
    local label = entry.label
    label:ClearAllPoints()
    for _, anchor in ipairs(Points(refLabel, refButton)) do
        local relativeTo = anchor.onButton and entry.button or anchor.relativeTo
        label:SetPoint(anchor.point, relativeTo, anchor.relativePoint, anchor.x * factor, anchor.y * factor)
    end
    -- One anchor: the size is the label's own; two or more set it.
    if refLabel:GetNumPoints() == 1 and type(refLabel.GetWidth) == "function" then
        SetSize(label, refLabel:GetWidth() * factor, refLabel:GetHeight() * factor)
    end
    SetJustify(label, type(refLabel.GetJustifyH) == "function" and refLabel:GetJustifyH() or nil)
end

local function PlaceOwn(entry, own)
    local label = entry.label
    label:ClearAllPoints()
    for _, anchor in ipairs(own.points) do
        local relativeTo = anchor.onButton and entry.button or anchor.relativeTo
        label:SetPoint(anchor.point, relativeTo, anchor.relativePoint, anchor.x, anchor.y)
    end
    if #own.points == 1 then
        SetSize(label, own.width, own.height)
    end
    SetJustify(label, own.justify)
end

function WTF.RefreshKeyLabels()
    local settings = WTF.db and WTF.db.keyLabels
    local on = settings and settings.petNormal
    local base = UIParent:GetEffectiveScale()
    local place = not InCombatLockdown()
    pendingPlace = not place
    local refButton, refLabel = Reference()
    for _, entry in ipairs(PetLabels()) do
        local own = Own(entry)
        if own then
            local factor
            local scale = entry.button:GetEffectiveScale()
            if on and type(scale) == "number" and scale > 0 and type(base) == "number" and base > 0 then
                factor = base / scale
            end
            entry.label:SetFont(own.font, factor and own.size * factor or own.size, own.flags)
            if place and own.points then
                if factor and refLabel then
                    PlaceLikeReference(entry, refButton, refLabel, factor)
                else
                    PlaceOwn(entry, own)
                end
            end
        end
    end
end

-- Edit Mode changes the pet bar's size when you save or leave it; the pet's
-- buttons are refreshed on PET_BAR_UPDATE, bindings can change the labels,
-- and the UI scale can change too. Anchors held back in combat follow at its
-- end.
local EVENTS = {"PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "PET_BAR_UPDATE", "UNIT_PET",
    "UPDATE_BINDINGS", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_REGEN_ENABLED"}

function WTF.InitializeKeyLabels()
    local frame = CreateFrame("Frame")
    for _, event in ipairs(EVENTS) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and not pendingPlace then
            return
        end
        WTF.RefreshKeyLabels()
    end)
    if EditModeManagerFrame and type(EditModeManagerFrame.HookScript) == "function" then
        EditModeManagerFrame:HookScript("OnHide", WTF.RefreshKeyLabels)
    end
    WTF.RefreshKeyLabels()
end
