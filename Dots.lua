local _, WTF = ...

-- Nameplate DoT dots: a small bubble above each hostile nameplate in combat,
-- one dot per DoT you know and chose for nameplates, in the tracker's colors;
-- a grey dot means the DoT is missing. Off by default (author-approved), as
-- it can get busy. Since 1.5.0 the engine is Dyre's Toolkit's (PlateDots.lua's
-- CreatePlateDots, 2.5.0, moved from here), on the DoT tracker's engine and
-- WTF's db.tracker settings.

local dots = {available = false}
local ART = "Interface\\AddOns\\Grimoire\\Textures\\"
local DOT_SIZE, DOT_GAP = 14, 2

-- At least one DoT you know, whatever the nameplate choices.
function WTF.HasTrackableDots()
    if not dots.available then
        return false
    end
    for _, slot in ipairs(WTF.DOT_SLOTS) do
        if slot.dot and WTF.TrackerKnowsSlot(slot.key) then
            return true
        end
    end
    return false
end

-- The colored dots are the bubbles' own regions, so they change color at once.
function WTF.ApplyDotColors()
    if dots.available then
        dots.engine:ApplyColors()
    end
end

function WTF.SetPlateDotsOpacity(percent)
    WTF.db.tracker.plateDotsOpacity = WTF.SanitizeWhole(percent, WTF.PLATE_DOTS_OPACITY_MIN,
        WTF.PLATE_DOTS_OPACITY_MAX, WTF.DEFAULT_PLATE_DOTS_OPACITY)
    if dots.available then
        dots.engine:ApplyOpacity()
    end
end

function WTF.RefreshPlateDots()
    if dots.available then
        dots.engine:Refresh()
    end
end

function WTF.InitializePlateDots()
    local tracker = WTF.DotTracker()
    if not tracker then
        return
    end
    -- 0.4.4: the dots in the game's own style, as class resource pips: each a
    -- gold ring, a dark socket while the DoT is missing and an orb in the
    -- DoT's color while it is up, with no box around them. The art is
    -- Grimoire's own (scripts/build_dot_art.py).
    local engine = WTF.shared.CreatePlateDots({tracker = tracker, store = WTF.db.tracker,
        dotSize = DOT_SIZE, dotGap = DOT_GAP, padding = 1,
        dress = function(bubble) bubble:SetBackdrop(nil) end,
        circle = function(parent, layer, r, g, b)
            local texture = parent:CreateTexture(nil, layer)
            texture:SetSize(DOT_SIZE, DOT_SIZE)
            -- The engine draws the missing DoT's dot on the bubble's BORDER
            -- layer, and the colored one on the aura slot's button over it.
            if layer == "BORDER" then
                texture:SetTexture(ART .. "DotEmpty")
                return texture
            end
            texture:SetTexture(ART .. "DotOrb")
            texture:SetVertexColor(r, g, b)
            local ring = parent:CreateTexture(nil, "OVERLAY")
            ring:SetTexture(ART .. "DotRing")
            ring:SetAllPoints(texture)
            return texture
        end,
        paint = function(texture, r, g, b) texture:SetVertexColor(r, g, b) end})
    if not engine then
        return
    end
    dots.engine = engine
    dots.available = true
end
