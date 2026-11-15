local _, WTF = ...

-- Grimoire: the pet bar's key labels keep their normal size. Edit Mode's
-- Icon Size scales a whole button, its key label too, and pet buttons are
-- smaller than action buttons, so a pet bar sized to match the other bars got
-- labels half again as big (user, 2026-11-15). Each label's font size is
-- divided by its button's scale against UIParent, so it shows at the size it
-- has at 100%, the size of the other bars' labels.
-- Only the font changes: a FontString is not protected, so this touches no
-- secure frame and works in combat too. Turned off, the labels get their own
-- font size back.

local PET_SLOTS = 10

local saved = {}

function WTF.SanitizeKeyLabels(settings)
    settings = type(settings) == "table" and settings or {}
    return {petNormal = settings.petNormal ~= false}
end

-- The pet buttons and their key labels, by the template's parentKey or the
-- named child, whichever the client has.
local function PetLabels()
    local found = {}
    for index = 1, (tonumber(NUM_PET_ACTION_SLOTS) or PET_SLOTS) do
        local name = "PetActionButton" .. index
        local button = _G[name]
        local label = button and (button.HotKey or _G[name .. "HotKey"])
        if label and type(label.GetFont) == "function" and type(button.GetEffectiveScale) == "function" then
            found[#found + 1] = {button = button, label = label}
        end
    end
    return found
end

function WTF.RefreshKeyLabels()
    local settings = WTF.db and WTF.db.keyLabels
    local on = settings and settings.petNormal
    local base = UIParent:GetEffectiveScale()
    for _, entry in ipairs(PetLabels()) do
        local label = entry.label
        -- The client's own font, read once before any change.
        if not saved[label] then
            local font, size, flags = label:GetFont()
            if font and size then
                saved[label] = {font = font, size = size, flags = flags}
            end
        end
        local own = saved[label]
        if own then
            local size = own.size
            local scale = entry.button:GetEffectiveScale()
            if on and type(scale) == "number" and scale > 0 and type(base) == "number" and base > 0 then
                size = own.size * base / scale
            end
            label:SetFont(own.font, size, own.flags)
        end
    end
end

-- Edit Mode changes the pet bar's size when you save or leave it; the pet's
-- buttons are refreshed on PET_BAR_UPDATE, and the UI scale can change too.
local EVENTS = {"PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "PET_BAR_UPDATE", "UNIT_PET",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}

function WTF.InitializeKeyLabels()
    local frame = CreateFrame("Frame")
    for _, event in ipairs(EVENTS) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function()
        WTF.RefreshKeyLabels()
    end)
    if EditModeManagerFrame and type(EditModeManagerFrame.HookScript) == "function" then
        EditModeManagerFrame:HookScript("OnHide", WTF.RefreshKeyLabels)
    end
    WTF.RefreshKeyLabels()
end
