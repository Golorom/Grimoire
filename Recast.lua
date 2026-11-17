local _, WTF = ...

-- Grimoire: the recast cue. A DoT with a cast time has to be started before
-- the old one runs out, or the mob spends the cast without it. The cue marks
-- a DoT's slot on the DoT tracker when it is time to start casting:
--
--   time left on the DoT  <=  the spell's cast time  +  your lead time
--
-- so a cast started at the cue lands about as the old DoT ends. An instant
-- DoT is marked one lead time before it ends. The mark goes when the DoT is
-- recast or gone, and while you are casting that spell at that mob.
--
-- Addon code cannot read a DoT's timer on Forever (the game draws the
-- tracker's timers itself), so the time left is the predictor's own clock:
-- your cast, the spell's duration, and the first tick seen (Predict; with
-- Wrack's faster ticks counted). It needs Predict available, not shown. The
-- cast time is the game's (C_Spell.GetSpellInfo), so talents that shorten a
-- cast count; when it reads secret, the last readable value stands.
--
-- Not known yet: whether Forever carries part of the old DoT's time over to
-- the new one (the client has C_UnitAuras.GetRefreshCarryOverDuration). If it
-- does, an earlier recast loses nothing and the lead can be longer.
--
-- The mark is the cue's own frame, a child of UIParent laid over the slot's
-- icon; the tracker's rows are never touched.

local TICK = 0.1
local EDGE = 2
local COLOR = {1, 0.95, 0.4}
-- The tracker's slot for each family the predictor times.
local SLOT_OF = {corruption = "corruption", immolate = "immolate", siphon = "siphon", agony = "bane"}
local FAMILY_ORDER = {"corruption", "agony", "immolate", "siphon"}
WTF.RECAST_LEAD_MIN, WTF.RECAST_LEAD_MAX, WTF.DEFAULT_RECAST_LEAD = 0, 20, 5

local recast = {marks = {}, castSeconds = {}, shown = {}}
local frame

-- lead: tenths of a second.
function WTF.SanitizeRecast(saved)
    saved = type(saved) == "table" and saved or {}
    return {
        enabled = saved.enabled ~= false,
        lead = WTF.SanitizeWhole(saved.lead, WTF.RECAST_LEAD_MIN, WTF.RECAST_LEAD_MAX, WTF.DEFAULT_RECAST_LEAD),
    }
end

-- The spell's cast time in seconds now; the last readable one when the game
-- hides it; 0 when it never read.
local function CastSeconds(spellID)
    local seconds
    if type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function" and type(spellID) == "number" then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and not WTF.IsSecret(info) and type(info) == "table" then
            local milliseconds = info.castTime
            if not WTF.IsSecret(milliseconds) and type(milliseconds) == "number" and milliseconds >= 0 then
                seconds = milliseconds / 1000
            end
        end
    end
    if seconds then
        recast.castSeconds[spellID] = seconds
        return seconds, true
    end
    return recast.castSeconds[spellID] or 0, false
end

-- The family of a spell you cast, by its ID or its name.
local function FamilyOf(spellID)
    if WTF.IsSecret(spellID) or type(spellID) ~= "number" then
        return nil
    end
    local data = WTF.shared and type(WTF.shared.ClassSpells) == "function" and WTF.shared.ClassSpells("WARLOCK")
    local rank = data and data.ranks and data.ranks[spellID]
    if rank then
        return rank[1]
    end
    local predictor = WTF.predictor
    local name = WTF.shared and type(WTF.shared.SpellName) == "function" and WTF.shared.SpellName(spellID)
    return predictor and name and predictor.byName and predictor.byName[name] or nil
end

-- Seconds until the cue for this DoT, and its time left: at or below 0 the
-- cue is due.
local function Due(dot, now)
    local left = dot.applied + dot.duration - now
    local cast = CastSeconds(dot.rank)
    return left - cast - WTF.db.recast.lead / 10, left, cast
end

local function MakeMark(region)
    local mark = CreateFrame("Frame", nil, UIParent)
    mark:SetFrameStrata("HIGH")
    mark:SetAllPoints(region)
    mark.edges = {}
    for index, edge in ipairs({{"TOPLEFT", "TOPRIGHT", true}, {"BOTTOMLEFT", "BOTTOMRIGHT", true},
            {"TOPLEFT", "BOTTOMLEFT", false}, {"TOPRIGHT", "BOTTOMRIGHT", false}}) do
        local texture = mark:CreateTexture(nil, "OVERLAY")
        texture:SetColorTexture(COLOR[1], COLOR[2], COLOR[3], 1)
        texture:SetPoint(edge[1], mark, edge[1], 0, 0)
        texture:SetPoint(edge[2], mark, edge[2], 0, 0)
        if edge[3] then
            texture:SetHeight(EDGE)
        else
            texture:SetWidth(EDGE)
        end
        mark.edges[index] = texture
    end
    local fill = mark:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints(mark)
    fill:SetColorTexture(COLOR[1], COLOR[2], COLOR[3], 0.25)
    mark.fill = fill
    mark.region = region
    mark:Hide()
    return mark
end

local function Visible(region)
    if type(region.IsVisible) ~= "function" then
        return true
    end
    local visible = region:IsVisible()
    return WTF.IsSecret(visible) or visible == true
end

-- Each tracker row with the mob it shows: the pinned target and focus rows,
-- then the list's rows.
local function Rows(tracker, predictor)
    local rows = {}
    for _, unit in ipairs({"target", "focus"}) do
        local row = type(tracker.pinned) == "table" and tracker.pinned[unit]
        if row and UnitExists(unit) then
            rows[#rows + 1] = {row = row, key = predictor.Key(unit)}
        end
    end
    for _, row in ipairs(type(tracker.rows) == "table" and tracker.rows or {}) do
        if row.guid then
            rows[#rows + 1] = {row = row, key = row.guid}
        end
    end
    return rows
end

local function HideAll()
    for _, mark in pairs(recast.marks) do
        mark:Hide()
    end
    recast.shown = {}
end

-- Which slots are due now, and their marks shown or hidden.
local function Update()
    local predictor = WTF.predictor
    local tracker = WTF.DotTracker and WTF.DotTracker()
    if not WTF.db.recast.enabled or not predictor or not tracker or type(predictor.Key) ~= "function" then
        HideAll()
        return
    end
    local now = GetTime()
    local wanted, shown = {}, {}
    if next(predictor.mobs) then
        local casting = recast.casting
        for _, entry in ipairs(Rows(tracker, predictor)) do
            local mob = entry.key and predictor.mobs[entry.key]
            local icons = entry.row.slotIcons
            if mob and type(icons) == "table" then
                for family, dot in pairs(mob.dots) do
                    local region = icons[SLOT_OF[family] or ""]
                    local mine = casting and casting.family == family and casting.key == entry.key
                    if region and not mine and not dot.doubtful and Due(dot, now) <= 0 and Visible(region) then
                        wanted[region] = true
                        shown[#shown + 1] = {key = entry.key, family = family}
                    end
                end
            end
        end
    end
    for region in pairs(wanted) do
        if not recast.marks[region] then
            recast.marks[region] = MakeMark(region)
        end
    end
    -- A slow pulse, so the mark reads as "now" and not as part of the row.
    local alpha = 0.55 + 0.45 * math.abs(math.sin(now * 4))
    for region, mark in pairs(recast.marks) do
        if wanted[region] then
            mark:SetAlpha(alpha)
            mark:Show()
        else
            mark:Hide()
        end
    end
    recast.shown = shown
end

-- Settings changed.
function WTF.RefreshRecast()
    if frame then
        Update()
    end
end

-- The slots marked now: {key, family}, for tests and the debug command.
function WTF.RecastCues()
    return recast.shown
end

local function OnUpdate(self, elapsed)
    self.waited = (self.waited or 0) + elapsed
    if self.waited < TICK then
        return
    end
    self.waited = 0
    -- A cast that went off: by now the predictor has the new DoT.
    if recast.casting and recast.casting.done then
        recast.casting = nil
    end
    -- Nothing timed and nothing marked: the clock stops until your next cast.
    local predictor = WTF.predictor
    if (not predictor or not next(predictor.mobs)) and #recast.shown == 0 then
        self:SetScript("OnUpdate", nil)
        return
    end
    Update()
end

local STOPS = {UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_SUCCEEDED = true}

function WTF.InitializeRecast()
    frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    for event in pairs(STOPS) do
        frame:RegisterUnitEvent(event, "player")
    end
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:SetScript("OnEvent", function(_, event, _, _, spellID)
        local predictor = WTF.predictor
        local family = (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED") and FamilyOf(spellID)
        if family and not (predictor and type(predictor.Key) == "function") then
            family = nil
        end
        if event == "UNIT_SPELLCAST_START" then
            recast.casting = family and {family = family, key = predictor.Key("target")} or nil
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" and family then
            -- The DoT went off (an instant one has no start). Its slot stays
            -- unmarked until the next tick of the clock, when the predictor
            -- has the new DoT: no flicker between the two.
            local key = recast.casting and recast.casting.family == family and recast.casting.key
                or predictor.Key("target")
            recast.casting = {family = family, key = key, done = true}
        elseif STOPS[event] then
            recast.casting = nil
        end
        Update()
        -- The clock runs from a cast until no DoT is timed any more: no
        -- OnUpdate while nothing is tracked.
        frame.waited = 0
        frame:SetScript("OnUpdate", OnUpdate)
    end)
end

-- /grim debug_recast: each timed DoT on your target and focus, its time
-- left, cast time, and when its cue comes.
function WTF.ReportRecastDebug()
    local settings = WTF.db.recast
    local predictor = WTF.predictor
    local tracker = WTF.DotTracker and WTF.DotTracker()
    WTF.Report(string.format("debug_recast enabled=%s lead=%.1fs predictor=%s tracker=%s marks=%d shown=%d",
        tostring(settings.enabled), settings.lead / 10, tostring(predictor ~= nil), tostring(tracker ~= nil),
        (function() local count = 0 for _ in pairs(recast.marks) do count = count + 1 end return count end)(),
        #recast.shown))
    if not predictor or type(predictor.Key) ~= "function" then
        WTF.Report("The recast cue needs DoT prediction, which is off on this client.")
        return
    end
    local now, any = GetTime(), false
    for _, unit in ipairs({"target", "focus"}) do
        local key = UnitExists(unit) and predictor.Key(unit)
        local mob = key and predictor.mobs[key]
        if mob then
            for _, family in ipairs(FAMILY_ORDER) do
                local dot = mob.dots[family]
                if dot then
                    any = true
                    local due, left, cast = Due(dot, now)
                    local _, readable = CastSeconds(dot.rank)
                    WTF.Report(string.format("  %s %s (spell %d): %.1fs left, cast %.1fs%s, cue %s", unit, family,
                        dot.rank, left, cast, readable and "" or " (last readable)",
                        due <= 0 and "now" or string.format("in %.1fs", due)))
                end
            end
        end
    end
    if not any then
        WTF.Report("  No timed DoT of yours on your target or focus.")
    end
end
