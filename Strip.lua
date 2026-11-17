local _, WTF = ...

-- The prep strip (0.3.5, a choice, off by default): the Stones buttons, the
-- shard counter, the reminder icons, and the Nightfall icon (0.3.6) in one
-- bar that moves and takes its look as one, in Edit Mode. Off, each is its
-- own frame as before.
--
-- Empty slots (0.3.6): a member whose switch is on but which hides for now
-- (your armor is on, your demon is out, no Nightfall) leaves its slot empty
-- (Show), shows a dim icon there (Faded, the default), or gives it up (Close
-- up). Secure buttons cannot move in combat, so the strip changes only out
-- of combat. The demon icon is last: in Close up, if your demon dies in
-- combat its icon shows just past the strip's end. Whether Nightfall is up
-- cannot be read in combat, so its slot always stays.
--
-- Turning the strip on or off takes effect after a reload, because Edit Mode
-- keeps a frame once it has one.

local BUTTON_SIZE, PADDING = 36, 6
local DEFAULT_POINT = {"CENTER", "CENTER", 260, -140}
local PLACEHOLDER_ALPHA = 0.35
local STRIP_JOB = {}
WTF.STRIP_EMPTY = {{key = "show", label = "Show"}, {key = "faded", label = "Faded"},
    {key = "close", label = "Close up"}}

local strip = {members = {}}
local frame

function WTF.SanitizeStrip(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    local clean = {enabled = saved.enabled == true, position = sanitizePosition(saved.position),
        scale = WTF.SanitizeFrameScale(saved.scale), empty = WTF.SanitizeChoice(saved.empty, WTF.STRIP_EMPTY, "faded")}
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

local function Icon(member)
    local region = member.frame.icon or member.frame.sample
    return region and type(region.GetTexture) == "function" and region:GetTexture() or nil
end

-- Which members get a slot, in order: those switched on, and in Close up
-- only those showing (Nightfall's slot always stays). The demon is last,
-- placed even when it gives up its slot.
local function Slots()
    local close = WTF.db.strip.empty == "close"
    local slots, trailing = {}, nil
    for _, member in ipairs(strip.members) do
        if member.wanted() then
            local showing = member.frame:IsShown() or member.keepsSlot
            if not close or showing then
                slots[#slots + 1] = member
            elseif member.last then
                trailing = member
            end
        end
    end
    return slots, trailing
end

local function Signature()
    local settings = WTF.db.strip
    local parts = {tostring(WTF.db.locked), settings.layout, settings.spacing, tostring(settings.background),
        settings.empty}
    for _, member in ipairs(strip.members) do
        parts[#parts + 1] = tostring(member.wanted() and true) .. tostring(member.frame:IsShown())
            .. tostring(member.frame:GetParent() == frame) .. tostring(Icon(member))
    end
    return table.concat(parts, ",")
end

local function Put(member, index)
    local settings = WTF.db.strip
    local offset = PADDING + (index - 1) * (BUTTON_SIZE + settings.spacing)
    local target = member.frame
    -- A member drawn at another size is scaled to the slot; offsets are in its own units.
    local scale = BUTTON_SIZE / member.native
    target:SetScale(scale)
    target:SetSize(member.native, member.native)
    target:ClearAllPoints()
    if settings.layout == "vertical" then
        target:SetPoint("TOP", frame, "TOP", 0, -offset / scale)
    else
        target:SetPoint("LEFT", frame, "LEFT", offset / scale, 0)
    end
    return offset
end

local function Placeholder(index)
    strip.placeholders = strip.placeholders or {}
    local texture = strip.placeholders[index]
    if not texture then
        texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        texture:SetDesaturated(true)
        texture:SetAlpha(PLACEHOLDER_ALPHA)
        strip.placeholders[index] = texture
    end
    return texture
end

-- Out of combat: members join the strip and take their slots. Nothing
-- changes while the switches, the members shown and the look stay the same.
local function Layout()
    local signature = Signature()
    if signature == strip.signature or strip.busy then
        return
    end
    -- Showing a member here must not start another layout.
    strip.busy = true
    table.sort(strip.members, function(a, b) return a.order < b.order end)
    for _, member in ipairs(strip.members) do
        if member.frame:GetParent() ~= frame then
            member.frame:SetParent(frame)
        end
        if member.showByStrip then
            member.frame:SetShown(member.wanted())
        end
    end
    local settings = WTF.db.strip
    local slots, trailing = Slots()
    local faded = settings.empty ~= "show"
    for index, member in ipairs(slots) do
        local offset = Put(member, index)
        local texture = Placeholder(index)
        texture:ClearAllPoints()
        if settings.layout == "vertical" then
            texture:SetPoint("TOP", frame, "TOP", 0, -offset)
        else
            texture:SetPoint("LEFT", frame, "LEFT", offset, 0)
        end
        texture:SetTexture(Icon(member))
        texture:SetShown(faded)
    end
    for index = #slots + 1, #(strip.placeholders or {}) do
        strip.placeholders[index]:Hide()
    end
    if trailing then
        Put(trailing, #slots + 1)
    end
    local long = PADDING * 2 + BUTTON_SIZE * #slots + settings.spacing * math.max(0, #slots - 1)
    local short = PADDING * 2 + BUTTON_SIZE
    local vertical = settings.layout == "vertical"
    frame:SetSize(vertical and short or long, vertical and long or short)
    WTF.SetBarBackground(frame, settings.background)
    frame:SetShown(#slots > 0 or trailing ~= nil or not WTF.db.locked)
    strip.signature = Signature()
    strip.busy = false
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
    if frame and not strip.busy then
        OutOfCombat(STRIP_JOB, Layout)
    end
end

-- A member: its frame, its place (lower first), whether its switch is on,
-- and options: showByStrip (the strip shows and hides it, else its module),
-- native (its own size, scaled to the slot), keepsSlot (its slot stays in
-- Close up), last (placed after the others even when it gives up its slot).
function WTF.JoinStrip(member, order, wanted, options)
    if not frame then
        return false
    end
    options = type(options) == "table" and options or {showByStrip = options == true}
    strip.members[#strip.members + 1] = {frame = member, order = order, wanted = wanted,
        showByStrip = options.showByStrip == true, native = options.native or BUTTON_SIZE,
        keepsSlot = options.keepsSlot == true, last = options.last == true}
    -- A member that shows or hides (out of combat, or the demon in combat)
    -- moves the others when combat allows.
    if type(member.HookScript) == "function" then
        member:HookScript("OnShow", WTF.RefreshStrip)
        member:HookScript("OnHide", WTF.RefreshStrip)
    end
    WTF.RefreshStrip()
    return true
end

function WTF.SetStripLook(key, value)
    local settings = WTF.db.strip
    if key == "empty" then
        settings.empty = WTF.SanitizeChoice(value, WTF.STRIP_EMPTY, "faded")
    else
        local saved = {layout = settings.layout, spacing = settings.spacing, background = settings.background}
        saved[key] = value
        WTF.SanitizeButtonBar(saved, settings, WTF.STONES_SPACING_DEFAULT, true)
    end
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

local function AddEditModeSettings()
    WTF.AddButtonBarSettings(frame, {settings = function() return WTF.db.strip end, setLook = WTF.SetStripLook,
        setScale = WTF.SetStripScale, spacing = WTF.STONES_SPACING_DEFAULT, background = true,
        what = "the strip",
        extra = function(kinds)
            local values = {}
            for _, choice in ipairs(WTF.STRIP_EMPTY) do
                values[#values + 1] = {text = choice.label, value = choice.key}
            end
            return {{kind = kinds.Dropdown, name = "Empty slots", default = "faded", values = values,
                get = function() return WTF.db.strip.empty end,
                set = function(_, value) WTF.SetStripLook("empty", value) end,
                desc = "A slot whose icon hides for now (armor on, demon out, no Nightfall). Show: an empty slot. "
                    .. "Faded: a dim icon. Close up: the others move up, out of combat; Nightfall keeps its slot."}}
        end})
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
    AddEditModeSettings()
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
            .. (member.frame:IsShown() and "" or " (hidden)")
    end
    return {"strip " .. WTF.db.strip.empty .. ": " .. table.concat(names, ", ")}
end
