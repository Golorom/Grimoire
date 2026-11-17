local _, WTF = ...

-- The prep strip (0.3.5, a choice, off by default): the Stones buttons, the
-- shard counter, and the reminder icons in one bar that moves and takes its
-- look as one, in Edit Mode. Off, each is its own frame as before.
--
-- Each member keeps its slot while its switch is on, also while it hides:
-- the demon icon can show in combat, and secure buttons cannot move then.
-- The Nightfall icon pops up in combat, so it stays a frame of its own.
-- Turning the strip on or off takes effect after a reload, because Edit Mode
-- keeps a frame once it has one.

local BUTTON_SIZE, PADDING = 36, 6
local DEFAULT_POINT = {"CENTER", "CENTER", 260, -140}
local STRIP_JOB = {}

local strip = {members = {}}
local frame

function WTF.SanitizeStrip(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    local clean = {enabled = saved.enabled == true, position = sanitizePosition(saved.position),
        scale = WTF.SanitizeFrameScale(saved.scale)}
    return WTF.SanitizeButtonBar(saved, clean, WTF.STONES_SPACING_DEFAULT, true)
end

-- Decided once, at login.
function WTF.StripActive()
    return strip.active == true
end

-- Until it is moved, the strip starts where the Stones bar was.
local function Place()
    local position = WTF.db.strip.position or WTF.db.stones.position
    frame:ClearAllPoints()
    if position then
        frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        frame:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[2], DEFAULT_POINT[3], DEFAULT_POINT[4])
    end
end

-- Out of combat: members join the strip, those switched on get a slot.
-- Nothing changes while the switches and the look stay the same.
local function Signature()
    local parts = {tostring(WTF.db.locked), WTF.db.strip.layout, WTF.db.strip.spacing,
        tostring(WTF.db.strip.background)}
    for _, member in ipairs(strip.members) do
        parts[#parts + 1] = tostring(member.wanted() and true) .. tostring(member.frame:GetParent() == frame)
    end
    return table.concat(parts, ",")
end

local function Layout()
    local signature = Signature()
    if signature == strip.signature then
        return
    end
    strip.signature = signature
    table.sort(strip.members, function(a, b) return a.order < b.order end)
    local list = {}
    for _, member in ipairs(strip.members) do
        if member.frame:GetParent() ~= frame then
            member.frame:SetParent(frame)
            member.frame:SetScale(1)
            member.frame:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        end
        local wanted = member.wanted()
        if member.showByStrip then
            member.frame:SetShown(wanted)
        end
        if wanted then
            list[#list + 1] = member.frame
        end
    end
    WTF.LayoutButtonBar(frame, list, WTF.db.strip, BUTTON_SIZE, PADDING)
    frame:SetShown(#list > 0 or not WTF.db.locked)
    strip.signature = Signature()
end

-- Out of combat; in combat, when it ends.
local function OutOfCombat(key, job)
    if WTF.shared then
        WTF.shared.OutOfCombat(key, job)
    elseif not InCombatLockdown() then
        job()
    end
end

function WTF.RefreshStrip()
    if frame then
        OutOfCombat(STRIP_JOB, Layout)
    end
end

-- A member: its frame, its place in the strip (lower first), whether its
-- switch is on, and whether the strip shows and hides it (else its module).
function WTF.JoinStrip(member, order, wanted, showByStrip)
    if not frame then
        return false
    end
    strip.members[#strip.members + 1] = {frame = member, order = order, wanted = wanted, showByStrip = showByStrip}
    WTF.RefreshStrip()
    return true
end

function WTF.SetStripLook(key, value)
    local settings = WTF.db.strip
    local saved = {layout = settings.layout, spacing = settings.spacing, background = settings.background}
    saved[key] = value
    WTF.SanitizeButtonBar(saved, settings, WTF.STONES_SPACING_DEFAULT, true)
    WTF.RefreshStrip()
end

local SCALE_JOB = {}
function WTF.SetStripScale(percent)
    WTF.db.strip.scale = WTF.SanitizeFrameScale(percent)
    if frame then
        OutOfCombat(SCALE_JOB, function() WTF.ScaleKeepingCenter(frame, WTF.db.strip.scale / 100) end)
    end
end

function WTF.ResetStripPosition()
    WTF.db.strip.position = nil
    if frame then
        OutOfCombat(frame, Place)
    end
end

function WTF.InitializeStrip()
    strip.active = WTF.db.strip.enabled
    if not strip.active then
        return
    end
    frame = CreateFrame("Frame", "GrimoireStrip", UIParent, "BackdropTemplate")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:SetSize(BUTTON_SIZE + PADDING * 2, BUTTON_SIZE + PADDING * 2)
    WTF.RegisterMovable(frame, function(position) WTF.db.strip.position = position end,
        {name = "Grimoire prep strip", default = WTF.EditModeDefault(DEFAULT_POINT)})
    WTF.AddButtonBarSettings(frame, {settings = function() return WTF.db.strip end, setLook = WTF.SetStripLook,
        setScale = WTF.SetStripScale, spacing = WTF.STONES_SPACING_DEFAULT, background = true,
        what = "the strip"})
    -- The saved place is in the strip's own scale, so the scale comes first.
    frame:SetScale(WTF.db.strip.scale / 100)
    Place()
    WTF.stripFrame = frame
end

function WTF.StripLines()
    if not frame then
        return {"strip off"}
    end
    local names = {}
    for _, member in ipairs(strip.members) do
        names[#names + 1] = (member.frame:GetName() or "counter") .. (member.wanted() and "" or " (off)")
    end
    return {"strip on: " .. table.concat(names, ", ")}
end
