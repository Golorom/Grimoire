local _, WTF = ...

-- A soft gold glow around a button that wants a click (0.3.1): a stone you
-- can make, a missing armor, a missing demon. Eight soft pieces just outside
-- the button (the textures are Hotbar Highlight's), pulsing slowly. A plain
-- frame on the button, never a secure one, so it shows and hides also in
-- combat.

local SIZE = 10
local COLOR = {1, 0.82, 0}
local PULSE_SECONDS = 0.8
local PULSE_LOW = 0.35
local FOLDER = "Interface\\AddOns\\Grimoire\\Textures\\"

-- Texture, its point and the button's point, and for an edge its second pair
-- of points and which side is SIZE.
local PIECES = {
    {"GlowTop", "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT", "TOPRIGHT", "height"},
    {"GlowBottom", "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", "height"},
    {"GlowLeft", "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", "width"},
    {"GlowRight", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "width"},
    {"GlowTopLeft", "BOTTOMRIGHT", "TOPLEFT"},
    {"GlowTopRight", "BOTTOMLEFT", "TOPRIGHT"},
    {"GlowBottomLeft", "TOPRIGHT", "BOTTOMLEFT"},
    {"GlowBottomRight", "TOPLEFT", "BOTTOMRIGHT"},
}

function WTF.CreateGlow(button)
    local glow = CreateFrame("Frame", nil, button)
    glow:SetAllPoints(button)
    glow:EnableMouse(false)
    glow.pieces = {}
    for index, piece in ipairs(PIECES) do
        local texture = glow:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(FOLDER .. piece[1])
        texture:SetVertexColor(COLOR[1], COLOR[2], COLOR[3])
        texture:SetBlendMode("ADD")
        texture:SetPoint(piece[2], button, piece[3], 0, 0)
        if piece[4] then
            texture:SetPoint(piece[4], button, piece[5], 0, 0)
            if piece[6] == "height" then
                texture:SetHeight(SIZE)
            else
                texture:SetWidth(SIZE)
            end
        else
            texture:SetSize(SIZE, SIZE)
        end
        glow.pieces[index] = texture
    end
    if type(glow.CreateAnimationGroup) == "function" then
        local pulse = glow:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(PULSE_LOW)
        fade:SetDuration(PULSE_SECONDS)
        fade:SetSmoothing("IN_OUT")
        glow.pulse = pulse
    end
    glow:Hide()
    return glow
end

-- Shows or hides a glow, pulsing while it shows.
function WTF.SetGlow(glow, shown)
    if not glow then
        return
    end
    shown = shown == true
    if glow:IsShown() ~= shown or (glow.pulse and glow.pulse:IsPlaying() ~= shown) then
        glow:SetShown(shown)
        if glow.pulse then
            if shown then
                glow.pulse:Play()
            else
                glow.pulse:Stop()
            end
        end
    end
end
