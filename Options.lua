local _, WTF = ...

-- The AddOn settings (0.4.0, each switch once):
--   Grimoire             which of its frames show, and which macros it keeps
--   Cues                 a grid: what Grimoire watches for you, and how each
--                        tells you (alert, its own icon, a glow on your bars)
--   Warnings             the alert window, and the lines about a fight
--   Soul Shards          deleting extras, the limit
--   DoTs                 nameplate dots, the curse slot, recast timing
--   Damage Prediction
--   DoT Order and Colors
--   Diagnostics
-- Vertical pages use Blizzard's layout with proxy settings that read and
-- write GrimoireDB directly; the Cues grid and the DoT order rows are canvas
-- pages. How frames look (sizes, layouts, colors) is set in each frame's
-- Edit Mode dialog, not on the pages (0.3.5).
local TITLE = "Grimoire"
local CUES_TITLE = "Cues"
local WARNINGS_TITLE = "Warnings"
local SHARDS_TITLE = "Soul Shards"
local TRACKER_TITLE = "DoTs"
local PREDICT_TITLE = "Damage Prediction"
local DOTS_TITLE = "DoT Order and Colors"
local DIAGNOSTICS_TITLE = "Diagnostics"
local UNAVAILABLE = "The AddOn settings page is unavailable on this client. Use /grim shards for status."
local GOLD = {1, 0.82, 0}

local REQUIRED_SETTINGS = {
    "RegisterVerticalLayoutCategory", "RegisterVerticalLayoutSubcategory", "RegisterCanvasLayoutSubcategory",
    "RegisterProxySetting", "RegisterAddOnCategory", "CreateCheckbox", "CreateSlider", "CreateSliderOptions",
    "CreateColorSwatch", "CreateDropdown", "CreateControlTextContainer",
    "OpenToCategory", "NotifyUpdate",
}

local category

local function HasSettingsAPI()
    if type(Settings) ~= "table" or type(Settings.VarType) ~= "table" then
        return false
    end
    for _, name in ipairs(REQUIRED_SETTINGS) do
        if type(Settings[name]) ~= "function" then
            return false
        end
    end
    return true
end

local function Proxy(page, variable, variableType, name, default, getValue, setValue)
    return Settings.RegisterProxySetting(page, variable, variableType, name, default, getValue, setValue)
end

-- A checkbox for one saved flag; onChange runs after the value is stored.
local function Flag(page, variable, name, group, key, default, tooltip, onChange)
    local setting = Proxy(page, variable, Settings.VarType.Boolean, name, default,
        function() return WTF.db[group][key] end,
        function(value)
            WTF.db[group][key] = value == true
            if onChange then
                onChange()
            end
        end)
    return Settings.CreateCheckbox(page, setting, tooltip)
end

-- 0.3.6: the glows on your action bars (Hotbar.lua).
local function RefreshHotbar()
    WTF.RefreshHotbar()
end

local function RefreshShardCounter()
    if WTF.RefreshShardCounter then
        WTF.RefreshShardCounter()
    end
end

local function RefreshStones()
    if WTF.RefreshStones then
        WTF.RefreshStones()
    end
end

-- A percent slider's value shows its % sign, so its label has no "(%)".
local function Percent(value)
    return string.format("%d%%", value)
end

-- format: true for percent, or a function for the value's text.
local function SliderOptions(minValue, maxValue, step, format)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
        local formatter = format == true and Percent or (type(format) == "function" and format or nil)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
    end
    return options
end

local function RefreshControl()
    WTF.RefreshControl()
end

-- A section heading, as Blizzard's Controls page adds them
-- (Blizzard_SettingControls.lua: CreateSettingsListSectionHeaderInitializer).
local function Heading(layout, name, tooltip)
    if type(CreateSettingsListSectionHeaderInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name, tooltip))
    end
end

-- How Fear, Banish, and your focus work (John, 1.3.1: "make sure we have
-- something that explains how the fear/focus works"): the page's heading
-- tooltip, and a button that says it in chat, line by line.
WTF.CONTROL_HELP = {
    "\"! Fear\" makes the mob under your mouse (else your target) your focus and fears it. "
        .. "Shift-press it to fear another mob and keep your focus.",
    "On a button whose key already holds Shift (bars on modifier keys), every press is the plain one: it "
        .. "sets your focus and fears it. Cast Fear itself to fear another mob and keep your focus.",
    "The Focus box above the Control bar shows your focus's Fear. Click it to fear your focus again; "
        .. "with no focus it does nothing.",
    "Every other mob you fear gets its own row, and a Fear timer under its nameplate.",
    "\"! Banish\" works the same way: it makes the mob your focus and banishes it. "
        .. "Click its row to banish your focus again.",
    "Where the game has no focus (Classic Era), the macros fear or banish the mob under your mouse, else "
        .. "your target; rows show the time left but take no clicks, and there is no Focus box.",
}

function WTF.ReportControlHelp()
    for _, line in ipairs(WTF.CONTROL_HELP) do
        WTF.Report(line)
    end
end

local function AddShardsSection(page, layout)
    Heading(layout, "Soul Shards", "Grimoire deletes Soul Shards that Drain Soul creates above your limit.")
    Flag(page, "GRIMOIRE_SHARDS_ENABLED", "Delete extra Soul Shards", "shards", "enabled", true,
        "Delete Soul Shards that Drain Soul creates above your limit. Shards you move into your bags are never "
            .. "deleted.")
    local auto = Proxy(page, "GRIMOIRE_SHARDS_AUTO_LIMIT", Settings.VarType.Boolean,
        "Match soul bag size", true,
        function() return WTF.db.shards.autoLimit end,
        function(value)
            local shards = WTF.db.shards
            -- Turning the soul bag match off starts the manual limit where it was.
            if shards.autoLimit and value == false then
                shards.limit = WTF.SanitizeShardLimit(WTF.GetShardLimit())
            end
            shards.autoLimit = value == true
            Settings.NotifyUpdate("GRIMOIRE_SHARDS_LIMIT")
            RefreshShardCounter()
        end)
    local autoInitializer = Settings.CreateCheckbox(page, auto,
        "Keep as many Soul Shards as your soul bags hold, or 6 without a soul bag.")

    -- Shows the limit in effect, including the soul bag size while matching it.
    local limit = Proxy(page, "GRIMOIRE_SHARDS_LIMIT", Settings.VarType.Number,
        "Shard limit", WTF.DEFAULT_SHARD_LIMIT,
        function() return (WTF.GetShardLimit()) end,
        function(value)
            if not WTF.db.shards.autoLimit then
                WTF.db.shards.limit = WTF.SanitizeShardLimit(value)
            end
            RefreshShardCounter()
        end)
    local options = Settings.CreateSliderOptions(WTF.SHARD_LIMIT_MIN, WTF.SHARD_LIMIT_MAX, 1)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    local limitInitializer = Settings.CreateSlider(page, limit, options,
        "How many Soul Shards to keep in your bags. Turn off Match soul bag size to change it.")
    limitInitializer:SetParentInitializer(autoInitializer, function()
        return not WTF.db.shards.autoLimit
    end)

    Flag(page, "GRIMOIRE_SHARDS_REPORT", "Report deletions in chat", "shards", "report", true,
        "Print one chat line for each Soul Shard Grimoire deletes. Off by default.")
    local low = Proxy(page, "GRIMOIRE_SHARDS_COUNTER_LOW", Settings.VarType.Number, "Few shards at",
        WTF.DEFAULT_SHARD_LOW,
        function() return WTF.db.shards.counterLow end,
        function(value)
            WTF.db.shards.counterLow = WTF.SanitizeShardLow(value)
            RefreshShardCounter()
        end)
    local lowOptions = Settings.CreateSliderOptions(WTF.SHARD_LOW_MIN, WTF.SHARD_LOW_MAX, 1)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(lowOptions.SetLabelFormatter) == "function" then
        lowOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    Settings.CreateSlider(page, low, lowOptions,
        "At this many Soul Shards or fewer the shard counter turns red and the Few Soul Shards alert (Cues page) "
            .. "shows.")
end

local function AddShardsPage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, SHARDS_TITLE)
    AddShardsSection(page, layout)
end

local function RefreshTracker()
    if WTF.RefreshTracker then
        WTF.RefreshTracker()
    end
end

local function RefreshPlateDots()
    if WTF.RefreshPlateDots then
        WTF.RefreshPlateDots()
    end
end

-- A gold mark on a slider's track at its default value (author-approved), as a
-- point of reference. Blizzard's settings slider has none, and the panel
-- reuses its slider frames for other settings, so the mark is drawn when this
-- setting's frame is set up and hidden whenever Blizzard releases the frame.
local TICK_WIDTH = 2
local TICK_HEIGHT = 12

local function PlaceTick(slider)
    local tick = slider.wtfDefaultTick
    local info = tick.info
    local thumb = slider:GetThumbTexture()
    local half = thumb and thumb:GetWidth() / 2 or 0
    local fraction = (info.default - info.minValue) / (info.maxValue - info.minValue)
    tick:ClearAllPoints()
    tick:SetPoint("CENTER", slider, "LEFT", half + fraction * (slider:GetWidth() - 2 * half), 0)
end

local function AddDefaultTick(initializer, minValue, maxValue, default)
    local baseInitFrame = initializer.InitFrame
    if type(baseInitFrame) ~= "function" then
        return
    end
    initializer.InitFrame = function(self, frame)
        baseInitFrame(self, frame)
        local slider = frame.SliderWithSteppers and frame.SliderWithSteppers.Slider
        if not slider then
            return
        end
        local tick = slider.wtfDefaultTick
        if not tick then
            tick = slider:CreateTexture(nil, "BORDER")
            tick:SetSize(TICK_WIDTH, TICK_HEIGHT)
            tick:SetColorTexture(GOLD[1], GOLD[2], GOLD[3])
            slider.wtfDefaultTick = tick
            slider:HookScript("OnSizeChanged", function()
                if tick:IsShown() then
                    PlaceTick(slider)
                end
            end)
            hooksecurefunc(frame, "Release", function()
                tick:Hide()
            end)
        end
        tick.info = {minValue = minValue, maxValue = maxValue, default = default}
        PlaceTick(slider)
        tick:Show()
    end
end

-- DoT damage prediction (John, 1.4.0): greyed where the Toolkit makes no
-- predictor (WoW: Forever with a Toolkit before 2.6, which reads the combat log
-- only); saved values stay as they are.
-- Grimoire: the engine is always here; the text stays empty.
local PREDICT_NEEDS = ""

-- The smart curse (John, 2026-11-10; Dyre's Toolkit 2.7.0): only with a
-- Toolkit that has it.
local SMART_CURSE_HELP = "Smart curse: with no modifier, Curse of Tongues on a mob with mana, else Curse of "
    .. "the Elements, else Curse of Weakness, chosen out of combat as your target changes. Shift casts Weakness, "
    .. "Ctrl Tongues (Weakness if you do not know Tongues), Alt Recklessness. The \"! Curse\" macro and the "
    .. "Smart curse key binding (Keybindings, AddOns) cast it too."

local function AddCurseSection(page, layout)
    if not (WTF.SmartCurseAvailable and WTF.SmartCurseAvailable()) then
        return
    end
    Heading(layout, "Curse slot", SMART_CURSE_HELP)
    local mode = Proxy(page, "GRIMOIRE_TRACKER_CURSE_MODE", Settings.VarType.String, "Curse slot click", "last",
        function() return WTF.db.tracker.curseMode end,
        function(value) WTF.SetCurseMode(value) end)
    Settings.CreateDropdown(page, mode, function()
        local container = Settings.CreateControlTextContainer()
        container:Add("last", "Last used")
        container:Add("smart", "Smart curse")
        return container:GetData()
    end, "What a click on the target or focus row's Curse slot casts. Last used: the curse you cast last. "
        .. SMART_CURSE_HELP .. " With Smart curse, a letter on the slot's icon names that mob's best curse: "
        .. "T Tongues, E Elements, W Weakness. A change in combat applies when combat ends.")
end

local function AddPredictPage(parent)
    local page = Settings.RegisterVerticalLayoutSubcategory(parent, PREDICT_TITLE)
    local function Refresh()
        WTF.RefreshPredict()
    end
    local enabled = Flag(page, "GRIMOIRE_PREDICT_ENABLED", "Show Predictive DoT Damage", "predict", "enabled", true,
        "Predictive DoT damage: a purple block on your target's health bar, ending where its health ends, "
            .. "and, with Show mob health on, on each DoT tracker row's, for the damage your "
            .. "Corruption, Curse of Agony, Immolate, and Siphon Life still have to deal. Each DoT's tick is "
            .. "learned from its first tick (on WoW: Forever, from the damage meter after combat); until then "
            .. "it is a guess from its rank and your spell power."
            .. PREDICT_NEEDS, Refresh)
    local plates = Flag(page, "GRIMOIRE_PREDICT_PLATES", "Also on nameplates", "predict", "plates", true,
        "The same block on each hostile nameplate's health bar." .. PREDICT_NEEDS, Refresh)
    local dies = Flag(page, "GRIMOIRE_PREDICT_DIES", "Show DIES", "predict", "dies", true,
        "\"DIES\" in red on the health bar when your DoTs will deal at least the mob's health." .. PREDICT_NEEDS,
        Refresh)
    local channels = Flag(page, "GRIMOIRE_PREDICT_CHANNELS", "Faster ticks while channeling Wrack", "predict",
        "channels", true,
        "While you channel Wrack, your Corruption, Siphon Life and Bane of Agony on that mob tick twice as "
            .. "fast, so the block shrinks twice as fast too. Does nothing until you have Wrack. Turn it off if "
            .. "the block runs ahead of the mob's health while you channel." .. PREDICT_NEEDS, Refresh)
    local function Choice(variable, name, key, choices, default, tooltip)
        local setting = Proxy(page, variable, Settings.VarType.String, name, default,
            function() return WTF.db.predict[key] end,
            function(value)
                WTF.db.predict[key] = WTF.SanitizeChoice(value, choices, default)
                Refresh()
            end)
        return Settings.CreateDropdown(page, setting, function()
            local container = Settings.CreateControlTextContainer()
            for _, choice in ipairs(choices) do
                container:Add(choice.key, choice.label)
            end
            return container:GetData()
        end, tooltip .. PREDICT_NEEDS)
    end
    local fill = Choice("GRIMOIRE_PREDICT_FILL", "Block style", "fill", WTF.PREDICT_FILLS, "stripes",
        "Dyre's stripes: diagonal stripes. WoW bar: the game's own texture of the bar it sits on, in the block's "
            .. "color. Solid color: one flat color. The same look on the target frame, nameplates, and DoT "
            .. "tracker rows.")
    local color = Choice("GRIMOIRE_PREDICT_COLOR", "Block color", "color", WTF.PREDICT_COLORS, "purple",
        "The block's color. On a bar of the same color, as a DoT tracker row in the panel's purple, the block is "
            .. "drawn lighter, so it stands out.")
    local opacitySetting = Proxy(page, "GRIMOIRE_PREDICT_OPACITY", Settings.VarType.Number, "Block opacity",
        WTF.DEFAULT_PREDICT_OPACITY,
        function() return WTF.db.predict.opacity end,
        function(value)
            WTF.db.predict.opacity = WTF.SanitizeWhole(value, WTF.PREDICT_OPACITY_MIN, WTF.PREDICT_OPACITY_MAX,
                WTF.DEFAULT_PREDICT_OPACITY)
            Refresh()
        end)
    local opacity = Settings.CreateSlider(page, opacitySetting,
        SliderOptions(WTF.PREDICT_OPACITY_MIN, WTF.PREDICT_OPACITY_MAX, 5, true),
        "How solid the block is, in percent." .. PREDICT_NEEDS)
    AddDefaultTick(opacity, WTF.PREDICT_OPACITY_MIN, WTF.PREDICT_OPACITY_MAX, WTF.DEFAULT_PREDICT_OPACITY)
    local outline = Choice("GRIMOIRE_PREDICT_OUTLINE", "Block outline", "outline", WTF.PREDICT_OUTLINES, "solid",
        "A thin line around the block, a little lighter than its color.")
    -- Where DIES goes (John, 2026-11-09): a place and X and Y offsets for the
    -- target and focus frames, and the same for nameplates.
    local function Offset(variable, name, key, tooltip)
        local setting = Proxy(page, variable, Settings.VarType.Number, name, 0,
            function() return WTF.db.predict[key] end,
            function(value)
                WTF.db.predict[key] = WTF.SanitizeWhole(value, WTF.DIES_OFFSET_MIN, WTF.DIES_OFFSET_MAX, 0)
                Refresh()
            end)
        local initializer = Settings.CreateSlider(page, setting,
            SliderOptions(WTF.DIES_OFFSET_MIN, WTF.DIES_OFFSET_MAX, 1), tooltip .. PREDICT_NEEDS)
        AddDefaultTick(initializer, WTF.DIES_OFFSET_MIN, WTF.DIES_OFFSET_MAX, 0)
        return initializer
    end
    local PLACE_TIP = "Auto puts it beside the bar, on a side nothing else uses. Center puts it in the middle of "
        .. "the bar."
    local diesPlace = Choice("GRIMOIRE_PREDICT_DIES_PLACE", "DIES place: target and focus", "diesPlace",
        WTF.DIES_PLACES, "auto", "Where DIES shows on your target and focus frames. " .. PLACE_TIP)
    local diesX = Offset("GRIMOIRE_PREDICT_DIES_X", "DIES left/right: target and focus", "diesX",
        "Moves DIES on your target and focus frames, in pixels: up to 100 left or right.")
    local diesY = Offset("GRIMOIRE_PREDICT_DIES_Y", "DIES down/up: target and focus", "diesY",
        "Moves DIES on your target and focus frames, in pixels: up to 100 down or up.")
    local plateDiesPlace = Choice("GRIMOIRE_PREDICT_PLATE_DIES_PLACE", "DIES place: nameplates", "plateDiesPlace",
        WTF.DIES_PLACES, "auto", "Where DIES shows on nameplates. " .. PLACE_TIP)
    local plateDiesX = Offset("GRIMOIRE_PREDICT_PLATE_DIES_X", "DIES left/right: nameplates", "plateDiesX",
        "Moves DIES on nameplates, in pixels: up to 100 left or right.")
    local plateDiesY = Offset("GRIMOIRE_PREDICT_PLATE_DIES_Y", "DIES down/up: nameplates", "plateDiesY",
        "Moves DIES on nameplates, in pixels: up to 100 down or up.")
    local function DiesOn() return WTF.db.predict.enabled and WTF.db.predict.dies end
    local function PlateDiesOn() return DiesOn() and WTF.db.predict.plates end
    for _, initializer in ipairs({diesPlace, diesX, diesY}) do
        initializer:SetParentInitializer(dies, DiesOn)
    end
    for _, initializer in ipairs({plateDiesPlace, plateDiesX, plateDiesY}) do
        initializer:SetParentInitializer(dies, PlateDiesOn)
    end
    for _, initializer in ipairs({fill, color, opacity, outline}) do
        initializer:SetParentInitializer(enabled, function() return WTF.db.predict.enabled end)
    end
    for _, initializer in ipairs({enabled, plates, dies, channels, fill, color, opacity, outline, diesPlace, diesX,
            diesY, plateDiesPlace, plateDiesX, plateDiesY}) do
        if type(initializer.AddModifyPredicate) == "function" then
            initializer:AddModifyPredicate(function() return WTF.PredictAvailable() end)
        end
    end
    plates:SetParentInitializer(enabled, function() return WTF.db.predict.enabled end)
    dies:SetParentInitializer(enabled, function() return WTF.db.predict.enabled end)
    channels:SetParentInitializer(enabled, function() return WTF.db.predict.enabled end)
end

-- Grimoire: when to start casting a DoT again (Recast.lua). 0.4.0: whether
-- it shows (the tracker's mark, the glow on your bars) is on the Cues page;
-- here is its timing and the mark's look.
local function AddRecastSection(page, layout)
    Heading(layout, "Recast timing", "When a DoT counts as due again, for the DoT to recast row on the Cues page.")
    local function Refresh()
        WTF.RefreshRecast()
    end
    local setting = Proxy(page, "GRIMOIRE_RECAST_LEAD", Settings.VarType.Number, "Lead time", WTF.DEFAULT_RECAST_LEAD,
        function() return WTF.db.recast.lead end,
        function(value)
            WTF.db.recast.lead = WTF.SanitizeWhole(value, WTF.RECAST_LEAD_MIN, WTF.RECAST_LEAD_MAX,
                WTF.DEFAULT_RECAST_LEAD)
            Refresh()
        end)
    local lead = Settings.CreateSlider(page, setting,
        SliderOptions(WTF.RECAST_LEAD_MIN, WTF.RECAST_LEAD_MAX, 1, function(value)
            return string.format("%.1f s", value / 10)
        end),
        "A DoT with a cast time is due when its time left is the cast time plus this lead, your reaction time "
            .. "and your lag, so a cast started then lands as the old one ends. Too long and the new DoT lands "
            .. "before the old one's last tick. An instant DoT is due as it runs out, after its last tick.")
    AddDefaultTick(lead, WTF.RECAST_LEAD_MIN, WTF.RECAST_LEAD_MAX, WTF.DEFAULT_RECAST_LEAD)
    -- 0.3.5: the mark's look.
    local styleSetting = Proxy(page, "GRIMOIRE_RECAST_STYLE", Settings.VarType.String, "Tracker mark look", "edges",
        function() return WTF.db.recast.style end,
        function(value)
            WTF.db.recast.style = WTF.SanitizeChoice(value, WTF.RECAST_STYLES, "edges")
            Refresh()
        end)
    local style = Settings.CreateDropdown(page, styleSetting, function()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(WTF.RECAST_STYLES) do
            container:Add(choice.key, choice.label)
        end
        return container:GetData()
    end, "The mark on a due DoT's slot on the tracker. Yellow edges: a pulsing yellow frame on the DoT's icon. "
        .. "Gold glow: a soft gold glow around it.")
    for _, initializer in ipairs({lead, style}) do
        if type(initializer.AddModifyPredicate) == "function" then
            initializer:AddModifyPredicate(function() return WTF.PredictAvailable() end)
        end
    end
end

-- 0.3.5: the tracker's look (theme, sizes, outline, mob health, panel colors
-- and opacity) is in its Edit Mode dialogs; this page keeps what it does:
-- the nameplate dots, the curse slot, and the recast timing.
local function AddTrackerPage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, TRACKER_TITLE)
    Heading(layout, "Nameplate dots", "A bubble of DoT dots above each hostile nameplate.")
    local dotsInitializer = Flag(page, "GRIMOIRE_TRACKER_PLATE_DOTS", "Show DoT dots on nameplates", "tracker",
        "plateDots", false,
        "In combat, a bubble above each hostile nameplate with a dot per DoT you know: colored while it is up, "
            .. "grey while it is missing. Needs at least one DoT you know. The DoT Order and Colors page chooses "
            .. "the dots.",
        RefreshPlateDots)
    if type(dotsInitializer.AddModifyPredicate) == "function" then
        dotsInitializer:AddModifyPredicate(function() return WTF.HasTrackableDots() end)
    end
    local offset = Proxy(page, "GRIMOIRE_TRACKER_PLATE_DOTS_OFFSET", Settings.VarType.Number,
        "Dot height above nameplates", WTF.DEFAULT_PLATE_DOTS_OFFSET,
        function() return WTF.db.tracker.plateDotsOffset end,
        function(value)
            WTF.db.tracker.plateDotsOffset = WTF.SanitizePlateDotsOffset(value)
            RefreshPlateDots()
        end)
    local offsetInitializer = Settings.CreateSlider(page, offset,
        SliderOptions(WTF.PLATE_DOTS_OFFSET_MIN, WTF.PLATE_DOTS_OFFSET_MAX, 1),
        "How far above the nameplate the dots sit, to clear other nameplate AddOns.")
    offsetInitializer:SetParentInitializer(dotsInitializer, function()
        return WTF.db.tracker.plateDots and WTF.HasTrackableDots()
    end)
    AddDefaultTick(offsetInitializer, WTF.PLATE_DOTS_OFFSET_MIN, WTF.PLATE_DOTS_OFFSET_MAX,
        WTF.DEFAULT_PLATE_DOTS_OFFSET)
    local opacity = Proxy(page, "GRIMOIRE_TRACKER_PLATE_DOTS_OPACITY", Settings.VarType.Number, "Nameplate dot opacity",
        WTF.DEFAULT_PLATE_DOTS_OPACITY,
        function() return WTF.db.tracker.plateDotsOpacity end,
        function(value) WTF.SetPlateDotsOpacity(value) end)
    local opacityInitializer = Settings.CreateSlider(page, opacity,
        SliderOptions(WTF.PLATE_DOTS_OPACITY_MIN, WTF.PLATE_DOTS_OPACITY_MAX, 5, true),
        "How solid the bubble of DoT dots above each nameplate is, in percent. It changes at once, also in combat.")
    opacityInitializer:SetParentInitializer(dotsInitializer, function()
        return WTF.db.tracker.plateDots and WTF.HasTrackableDots()
    end)
    AddDefaultTick(opacityInitializer, WTF.PLATE_DOTS_OPACITY_MIN, WTF.PLATE_DOTS_OPACITY_MAX,
        WTF.DEFAULT_PLATE_DOTS_OPACITY)
    AddCurseSection(page, layout)
    AddRecastSection(page, layout)
end

-- One color per slot, shared by the tracker's bars and the nameplate dots.
local function ApplyColors()
    if WTF.ApplyTrackerColors then
        WTF.ApplyTrackerColors()
    end
    if WTF.ApplyDotColors then
        WTF.ApplyDotColors()
    end
end

-- Canvas page helpers (from WTF's Announce page, which Grimoire drops).
local PAGE_LEFT = 16
local EDIT_WIDTH = 560

local function Text(parent, font, text)
    local label = parent:CreateFontString(nil, "ARTWORK", font)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function CheckButton(parent, template, label)
    local button = CreateFrame("CheckButton", nil, parent, template)
    button.label = Text(button, "GameFontHighlight", label)
    button.label:SetPoint("LEFT", button, "RIGHT", 4, 0)
    return button
end

local DOTS_ROW_HEIGHT = 30
local DOTS_ICON_SIZE = 22
local DOTS_ROW_WIDTH = 420
local DOTS_PLATE_LEFT = 220
local DOTS_SWATCH_LEFT = 380
local DOTS_SWATCH_SIZE = 20
local DOTS_BUTTON_WIDTH = 128
local DOTS_BUTTON_HEIGHT = 22
local DOTS_DRAG_ALPHA = 0.5
local DOTS_INSERT_HEIGHT = 2
local PLATES_OFF_TIP = "Turn on Show DoT dots on nameplates on the DoTs page to choose the dots."

local function SetDotOrder(order)
    WTF.db.tracker.order = WTF.SanitizeDotOrder(order)
    if WTF.ApplyDotOrder then
        WTF.ApplyDotOrder()
    end
    RefreshPlateDots()
end

-- The plate switches work only while the dots can show.
local function PlatesOn()
    return WTF.db.tracker.plateDots == true and WTF.HasTrackableDots and WTF.HasTrackableDots()
end

local function Tooltip(owner, text)
    if type(GameTooltip) ~= "table" then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

local function HideTooltip()
    if type(GameTooltip) == "table" then
        GameTooltip:Hide()
    end
end

local function HexOf(r, g, b)
    return string.format("ff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
end

local function SetDotColor(key, value)
    local default
    for _, slot in ipairs(WTF.DOT_SLOTS) do
        if slot.key == key then
            default = slot.color
        end
    end
    WTF.db.tracker.colors[key] = WTF.SanitizeColor(value, default)
    ApplyColors()
end

-- The game's color picker, as the Settings color swatch opens it
-- (Blizzard_SettingControls.lua: SettingsColorSwatchMixin); Cancel puts the
-- old color back.
local function PickColor(row)
    if type(ColorPickerFrame) ~= "table" or type(ColorPickerFrame.SetupColorPickerAndShow) ~= "function" then
        return
    end
    local key = row.key
    local r, g, b = WTF.SlotColor(key)
    ColorPickerFrame:SetupColorPickerAndShow({
        swatch = row.swatch, r = r, g = g, b = b,
        swatchFunc = function() SetDotColor(key, HexOf(ColorPickerFrame:GetColorRGB())) end,
        cancelFunc = function() SetDotColor(key, HexOf(ColorPickerFrame:GetPreviousValues())) end,
    })
end

local function CreateDotsPage()
    local page = CreateFrame("Frame")
    page.rows = {}
    local title = Text(page, "GameFontHighlightHuge", DOTS_TITLE)
    title:SetPoint("TOPLEFT", PAGE_LEFT, -16)
    local help = Text(page, "GameFontHighlightSmall",
        "Your DoTs in the order the DoT tracker's rows and the nameplate dots show them, the first one on top "
            .. "or at the left. Drag a row up or down to move it. A change made in combat reaches the tracker "
            .. "when combat ends; colors change at once.")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    help:SetWidth(EDIT_WIDTH)
    local insert = page:CreateTexture(nil, "OVERLAY")
    insert:SetColorTexture(GOLD[1], GOLD[2], GOLD[3])
    insert:SetHeight(DOTS_INSERT_HEIGHT)
    insert:Hide()
    page.insert = insert

    -- The gap under the cursor: 0 above the first row to #rows below the
    -- last, or nil when the cursor leaves the page (a drop there cancels).
    local function DropSlot()
        local scale = page:GetEffectiveScale()
        local x, y = GetCursorPosition()
        x, y = x / scale, y / scale
        local left, right, top, bottom = page:GetLeft(), page:GetRight(), page:GetTop(), page:GetBottom()
        if not (left and right and top and bottom) or x < left or x > right or y > top or y < bottom then
            return nil
        end
        local slot = 0
        for _, row in ipairs(page.rows) do
            local rowTop = row:GetTop()
            if rowTop and rowTop - DOTS_ROW_HEIGHT / 2 > y then
                slot = slot + 1
            end
        end
        return slot
    end

    local function PlaceInsertLine()
        local slot = DropSlot()
        if not slot then
            insert:Hide()
            return
        end
        local anchor = page.rows[math.max(slot, 1)]
        insert:ClearAllPoints()
        insert:SetPoint("LEFT", anchor, slot == 0 and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
        insert:SetWidth(DOTS_ROW_WIDTH)
        insert:Show()
    end

    local function StartReorder(row)
        row.reordering = true
        row:SetAlpha(DOTS_DRAG_ALPHA)
        row:SetScript("OnUpdate", PlaceInsertLine)
    end

    -- The gap counts the dragged row itself; a drop next to it changes nothing.
    local function StopReorder(row)
        if not row.reordering then
            return
        end
        row.reordering = nil
        row:SetScript("OnUpdate", nil)
        row:SetAlpha(1)
        insert:Hide()
        local slot = DropSlot()
        if not slot then
            return
        end
        local from = row.position
        if slot >= from then
            slot = slot - 1
        end
        if slot + 1 ~= from then
            local order = {}
            for index, key in ipairs(WTF.db.tracker.order) do
                order[index] = key
            end
            table.insert(order, slot + 1, table.remove(order, from))
            SetDotOrder(order)
        end
        page:OnRefresh()
    end

    local previous = help
    for position = 1, #WTF.DOT_SLOTS do
        local row = CreateFrame("Button", nil, page)
        row:SetSize(DOTS_ROW_WIDTH, DOTS_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, position == 1 and -16 or 0)
        row.position = position
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnDragStart", StartReorder)
        row:SetScript("OnDragStop", StopReorder)
        row:SetScript("OnEnter", function(self)
            Tooltip(self, "Drag up or down to move " .. self.label:GetText() .. ".")
        end)
        row:SetScript("OnLeave", HideTooltip)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(DOTS_ICON_SIZE, DOTS_ICON_SIZE)
        row.icon:SetPoint("LEFT", 0, 0)
        row.label = Text(row, "GameFontHighlight", "")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.plate = CheckButton(row, "UICheckButtonTemplate", "On nameplates")
        row.plate:SetPoint("LEFT", DOTS_PLATE_LEFT, 0)
        row.plate:SetScript("OnClick", function(self)
            WTF.db.tracker.onPlates[row.key] = self:GetChecked() == true
            RefreshPlateDots()
        end)
        -- A disabled button still shows its tooltip, which says why.
        row.plate:SetMotionScriptsWhileDisabled(true)
        row.plate:SetScript("OnEnter", function(self)
            Tooltip(self, PlatesOn() and ("Show a " .. row.label:GetText() .. " dot in the nameplate bubble.")
                or PLATES_OFF_TIP)
        end)
        row.plate:SetScript("OnLeave", HideTooltip)
        row.swatch = CreateFrame("Button", nil, row)
        row.swatch:SetSize(DOTS_SWATCH_SIZE, DOTS_SWATCH_SIZE)
        row.swatch:SetPoint("LEFT", DOTS_SWATCH_LEFT, 0)
        local edge = row.swatch:CreateTexture(nil, "BACKGROUND")
        edge:SetAllPoints()
        edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3])
        row.swatch.color = row.swatch:CreateTexture(nil, "ARTWORK")
        row.swatch.color:SetPoint("TOPLEFT", 1, -1)
        row.swatch.color:SetPoint("BOTTOMRIGHT", -1, 1)
        row.swatch:SetScript("OnClick", function() PickColor(row) end)
        row.swatch:SetScript("OnEnter", function(self)
            Tooltip(self, "The color of " .. row.label:GetText() .. " on the tracker's bars and on nameplate dots. "
                .. "Click to change it.")
        end)
        row.swatch:SetScript("OnLeave", HideTooltip)
        page.rows[position] = row
        previous = row
    end
    local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    reset:SetSize(DOTS_BUTTON_WIDTH, DOTS_BUTTON_HEIGHT)
    reset:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -12)
    reset:SetText("Reset order")
    reset:SetScript("OnClick", function()
        SetDotOrder(nil)
        page:OnRefresh()
    end)
    page.reset = reset

    function page:OnRefresh()
        local platesOn = PlatesOn()
        for position, slot in ipairs(WTF.OrderedDotSlots()) do
            local row = self.rows[position]
            row.key = slot.key
            row.label:SetText(slot.label)
            local texture = WTF.TrackerSlotIcon and WTF.TrackerSlotIcon(slot.key)
            if texture then
                row.icon:SetTexture(texture)
            else
                row.icon:SetColorTexture(WTF.SlotColor(slot.key))
            end
            row.plate:SetChecked(WTF.db.tracker.onPlates[slot.key] == true)
            row.plate:SetEnabled(platesOn)
            row.plate.label:SetTextColor(platesOn and 1 or 0.5, platesOn and 1 or 0.5, platesOn and 1 or 0.5)
            row.swatch.color:SetColorTexture(WTF.SlotColor(slot.key))
        end
    end

    -- The Settings panel's Defaults button restores this page only: the
    -- order, the colors, and the nameplate dots.
    function page:OnDefault()
        for _, slot in ipairs(WTF.DOT_SLOTS) do
            WTF.db.tracker.colors[slot.key] = slot.color
            WTF.db.tracker.onPlates[slot.key] = true
        end
        ApplyColors()
        SetDotOrder(nil)
        self:OnRefresh()
    end

    page:SetScript("OnShow", page.OnRefresh)
    return page
end

-- A slider with a number setting.
local function Slider(page, variable, name, default, getValue, setValue, minValue, maxValue, step, format, tooltip)
    local setting = Proxy(page, variable, Settings.VarType.Number, name, default, getValue, setValue)
    return Settings.CreateSlider(page, setting, SliderOptions(minValue, maxValue, step, format), tooltip)
end

local function ApplyProcSounds()
    if WTF.ApplyProcSounds then
        WTF.ApplyProcSounds()
    end
end

local function AddButton(layout, name, buttonText, click, tooltip)
    if type(CreateSettingsButtonInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsButtonInitializer(name, buttonText, click, tooltip, true))
    end
end

-- The Cues page (0.4.0): what Grimoire watches for you, a row each, and how
-- it tells you, a column each. A row is always watched; a tick only chooses
-- an output, so the armor's alert can be off and its glow on your bars stay.
--   alert  a line in the alert window (Nightfall: a sound)
--   icon   Grimoire's own icon on screen (a DoT: the mark on the tracker)
--   glow   the button on your action bars glows
-- A cell is {group, key} of a saved switch, with what to refresh; a string
-- names the frame that shows it instead; nil is no such output.
local function RefreshReminders() WTF.RefreshReminders() end
local function RefreshProcs() WTF.RefreshProcs() end
local function RefreshRecast() WTF.RefreshRecast() end

WTF.CUES = {
    {key = "armor", label = "Armor missing",
        help = "You have no Demon Armor or Demon Skin on. Checked out of combat.",
        alert = {group = "reminders", key = "armor", apply = RefreshReminders,
            tip = "A line while it is missing, again after 2, 5, then every 15 minutes, and a line a minute before "
                .. "it runs out. Quiet while you are dead, on a flight path, or resting in a city."},
        icon = {group = "reminders", key = "armorIcon", apply = RefreshReminders,
            tip = "A glowing armor icon while it is missing. Click it to cast."},
        glow = {group = "hotbar", key = "armor", apply = RefreshHotbar,
            tip = "Demon Armor or Demon Skin on your action bars glows while it is missing."}},
    {key = "demon", label = "No demon out",
        help = "You have no demon out. Checked out of combat.",
        alert = {group = "reminders", key = "demon", apply = RefreshReminders,
            tip = "A line after combat while you have no demon, repeating as the armor's."},
        icon = {group = "reminders", key = "demonIcon", apply = RefreshReminders,
            tip = "A glowing icon of your last demon while none is out. Click it to summon."},
        glow = {group = "hotbar", key = "demon", apply = RefreshHotbar,
            tip = "Your last demon's summon on your action bars glows while none is out."}},
    {key = "healthstone", label = "No Healthstone",
        help = "You have no Healthstone in your bags, and a Soul Shard to make one.",
        alert = {group = "stones", key = "remindHealthstone",
            tip = "A line on entering an instance, joining a group, or after a fight, at most every 10 minutes."},
        icon = "Stones bar",
        glow = {group = "hotbar", key = "healthstone", apply = RefreshHotbar,
            tip = "The \"! Healthstone\" macro, Create Healthstone, or the stone on your action bars glows."}},
    {key = "soulstone", label = "No Soulstone",
        help = "Nobody has your Soulstone on them.",
        alert = {group = "stones", key = "remindSoulstone",
            tip = "A line when your Soulstone ends, and at the Healthstone's times while none is up."},
        icon = "Stones bar",
        glow = {group = "hotbar", key = "soulstone", apply = RefreshHotbar,
            tip = "The \"! Soulstone\" macro, Create Soulstone, or the stone on your action bars glows, while you "
                .. "have none in your bags and can make one."}},
    {key = "shards", label = "Few Soul Shards",
        help = "You have few Soul Shards left. How few is set on the Soul Shards page, 2 by default.",
        alert = {group = "shards", key = "lowAlert", tip = "A line when you get down to that number, and when you run out."},
        icon = "Shard counter"},
    {key = "recast", label = "DoT to recast",
        help = "One of your DoTs on your target or focus is about to run out, or has run out.",
        icon = {group = "recast", key = "enabled", apply = RefreshRecast,
            tip = "The DoT's slot on the DoT tracker pulses."},
        glow = {group = "hotbar", key = "recast", apply = RefreshHotbar,
            tip = "The DoT on your action bars glows for your target, and its focus macro for your focus."}},
    {key = "nightfall", label = "Nightfall",
        help = "Nightfall procced. Your next Shadow Bolt is instant.",
        alert = {group = "procs", key = "sound", apply = ApplyProcSounds,
            tip = "A sound, the Imp's chirp, the moment it lands. Needs alert sounds on (Warnings page)."},
        icon = {group = "procs", key = "icon", apply = RefreshProcs,
            tip = "A Shadow Trance icon with its time left."},
        glow = {group = "hotbar", key = "nightfall", apply = RefreshHotbar,
            tip = "Your Shadow Bolt buttons glow. Not yet tested in game."}},
}

local CUE_COLUMNS = {{key = "alert", label = "Alert", left = 220}, {key = "icon", label = "Icon", left = 310},
    {key = "glow", label = "Action bar glow", left = 400}}
local CUE_ROW_HEIGHT = 30
local CUE_CHECK_SIZE = 26

local function CreateCuesPage()
    local page = CreateFrame("Frame")
    page.rows = {}
    local title = Text(page, "GameFontHighlightHuge", CUES_TITLE)
    title:SetPoint("TOPLEFT", PAGE_LEFT, -16)
    local help = Text(page, "GameFontHighlightSmall",
        "What Grimoire watches for you, and how each tells you: a line in the alert window, Grimoire's own icon, "
            .. "or a glow on the button on your action bars. A row is always watched; untick what you do not "
            .. "want to see. Point at a box for what it does.")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    help:SetWidth(EDIT_WIDTH)
    local header = CreateFrame("Frame", nil, page)
    header:SetSize(EDIT_WIDTH, CUE_ROW_HEIGHT)
    header:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -12)
    for _, column in ipairs(CUE_COLUMNS) do
        local text = Text(header, "GameFontNormal", column.label)
        text:SetPoint("LEFT", column.left, 0)
    end
    local previous = header
    for _, cue in ipairs(WTF.CUES) do
        local row = CreateFrame("Frame", nil, page)
        row:SetSize(EDIT_WIDTH, CUE_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
        row.key = cue.key
        row.label = Text(row, "GameFontHighlight", cue.label)
        row.label:SetPoint("LEFT", 0, 0)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self) Tooltip(self, cue.help) end)
        row:SetScript("OnLeave", HideTooltip)
        row.cells = {}
        for _, column in ipairs(CUE_COLUMNS) do
            local cell = cue[column.key]
            if type(cell) == "table" then
                local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                check:SetSize(CUE_CHECK_SIZE, CUE_CHECK_SIZE)
                check:SetPoint("LEFT", column.left, 0)
                check.cell = cell
                check:SetScript("OnClick", function(self)
                    WTF.db[cell.group][cell.key] = self:GetChecked() == true
                    if cell.apply then
                        cell.apply()
                    end
                end)
                check:SetScript("OnEnter", function(self) Tooltip(self, cell.tip) end)
                check:SetScript("OnLeave", HideTooltip)
                row.cells[column.key] = check
            elseif type(cell) == "string" then
                -- Shown by one of Grimoire's frames, which has its own switch.
                local text = Text(row, "GameFontDisableSmall", cell)
                text:SetPoint("LEFT", column.left, 0)
            end
        end
        page.rows[#page.rows + 1] = row
        previous = row
    end

    function page:OnRefresh()
        for _, row in ipairs(self.rows) do
            for _, check in pairs(row.cells) do
                check:SetChecked(WTF.db[check.cell.group][check.cell.key] == true)
            end
        end
    end

    -- The Settings panel's Defaults button: every output on.
    function page:OnDefault()
        local applied = {}
        for _, row in ipairs(self.rows) do
            for _, check in pairs(row.cells) do
                local cell = check.cell
                WTF.db[cell.group][cell.key] = true
                if cell.apply and not applied[cell.apply] then
                    applied[cell.apply] = true
                    cell.apply()
                end
            end
        end
        self:OnRefresh()
    end

    page:SetScript("OnShow", page.OnRefresh)
    return page
end

-- 0.4.0: the alert window, and the lines about a fight. What tells you about
-- your armor, demon, stones, shards, DoTs and Nightfall is on the Cues page.
local function AddWarningsPage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, WARNINGS_TITLE)
    Heading(layout, "Alert window", "Short lines for you only. A line shows at once, stays, then fades. "
        .. "Nothing is sent to other players. Its size, lines, background, hold and fade times are set in Edit "
        .. "Mode: select the window there.")
    AddButton(layout, "Test the alerts", "Show test alerts", WTF.TestAlerts,
        "Three sample lines, one of each color, with a sound. Same as /grim test.")
    Flag(page, "GRIMOIRE_ALERTS_ENABLED", "Show the alert window", "alerts", "enabled", true,
        "Off: alerts go to chat instead.", function() WTF.RefreshAlerts() end)
    Flag(page, "GRIMOIRE_ALERTS_CHAT", "Also print alerts in chat", "alerts", "chat", false,
        "Each alert also as a chat line. Chat addons that filter by addon (Chattynator) can put them in a tab.")
    Flag(page, "GRIMOIRE_ALERTS_SOUNDS", "Alert sounds", "alerts", "sounds", true,
        "The game sounds of the threat, demon, cooldown, and Nightfall alerts.", ApplyProcSounds)
    Heading(layout, "Threat", "Mobs that turn to you, or are about to.")
    local threat = Flag(page, "GRIMOIRE_THREAT_ENABLED", "Threat warning", "threat", "enabled", true,
        "A line when a mob your Voidwalker or a tank held turns to you: red with a sound in a group, yellow and "
            .. "silent when you are alone. Mobs you pull yourself never warn.")
    local risk = Flag(page, "GRIMOIRE_THREAT_RISK", "Warn before you pull", "threat", "risk", true,
        "In a group: a yellow line and a softer sound when your threat on a mob someone else holds reaches the "
            .. "percent below. Once per climb, and never after the mob turned to you.")
    local riskAt = Slider(page, "GRIMOIRE_THREAT_RISK_AT", "Warn at", WTF.DEFAULT_THREAT_RISK,
        function() return WTF.db.threat.riskAt end,
        function(value)
            WTF.db.threat.riskAt = WTF.SanitizeWhole(value, WTF.THREAT_RISK_MIN, WTF.THREAT_RISK_MAX,
                WTF.DEFAULT_THREAT_RISK)
        end, WTF.THREAT_RISK_MIN, WTF.THREAT_RISK_MAX, 5, true,
        "Your threat as a percent of what pulls the mob. 100 is the pull.")
    risk:SetParentInitializer(threat, function() return WTF.db.threat.enabled end)
    riskAt:SetParentInitializer(risk, function() return WTF.db.threat.enabled and WTF.db.threat.risk end)
    Heading(layout, "Your demon", "Warnings about your demon, in and out of combat.")
    Flag(page, "GRIMOIRE_PET_DIED", "Demon died", "pet", "died", true,
        "A red line and a sound when your demon dies in combat, and when Enslave Demon breaks.")
    Flag(page, "GRIMOIRE_THREAT_PET_LOST", "Demon lost a mob", "threat", "petLost", true,
        "A yellow line when a mob your demon held goes to someone else. When it goes to you, the aggro line "
            .. "says so instead.")
    Flag(page, "GRIMOIRE_PET_TAUNT", "Pet taunt warning", "pet", "taunt", true,
        "In a group where you are not the tank: a yellow line when your demon's taunt (Torment, Suffering, "
            .. "Anguish) is on autocast, and once more as a fight starts. Checked out of combat.",
        function() WTF.RefreshPetTaunt() end)
    Heading(layout, "Cooldowns", "A line just before a chosen spell is ready again, timed from your cast.")
    Flag(page, "GRIMOIRE_COOLDOWNS_ENABLED", "Cooldown alerts", "cooldowns", "enabled", true,
        "A line just before a chosen spell is ready again, timed from your cast.")
    for _, def in ipairs(WTF.COOLDOWN_SPELLS or {}) do
        local setting = Proxy(page, "GRIMOIRE_COOLDOWN_" .. def.key:upper(), Settings.VarType.Boolean,
            "  " .. def.label, def.on,
            function() return WTF.db.cooldowns.spells[def.key] end,
            function(value) WTF.db.cooldowns.spells[def.key] = value == true end)
        Settings.CreateCheckbox(page, setting, "A line when " .. def.label .. " is ready again.")
    end
end

-- Grimoire 0.2.1: the background diagnostics (Probe.lua) on a page of their own.
local function AddDiagnosticsPage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, DIAGNOSTICS_TITLE)
    Heading(layout, "Logs for fixing Grimoire", "What the game lets Grimoire read, counted while you play, and "
        .. "the last 100 alerts Grimoire showed. Kept in Grimoire's saved settings on your computer only: no "
        .. "names, nothing sent.")
    Flag(page, "GRIMOIRE_DIAGNOSTICS", "Collect logs", "diagnostics", "enabled", true,
        "While you play, Grimoire notes whether threat, spell cooldowns, pet health and cast times come back "
            .. "readable or hidden, in and out of combat, and which of its alerts showed when. The game writes them "
            .. "to disk when you log out, reload the interface, or quit.",
        function() WTF.RefreshDiagnostics() end)
    AddButton(layout, "See the logs", "Show in chat", WTF.ReportDiagnostics,
        "Print the counts, an answer for each open question, and the last alerts in your chat frame (only you "
            .. "see it). Same as /grim debug_log.")
    AddButton(layout, "Save the logs to disk now", "Save", WTF.SaveDiagnostics,
        "The game writes AddOn data to disk only when you log out, reload the interface, or quit; AddOns cannot "
            .. "write files themselves. This reloads the interface now (a short loading screen), out of combat "
            .. "only. Same as /grim debug_log_save.")
    AddButton(layout, "Start the logs over", "Clear", WTF.ResetDiagnostics,
        "Forget the counts and alerts collected so far. Same as /grim debug_log_reset.")
end

-- The main page: which of Grimoire's frames show, and which macros it keeps
-- for your action bars. Each frame moves and is styled in Edit Mode.
local function AddMainPage(layout)
    Heading(layout, "On screen", "Grimoire's own frames. Each moves in the game's Edit Mode: press Esc, then "
        .. "Edit Mode. It shows there with its name and a sample. Drag it, or select it and type exact "
        .. "coordinates. Select it to set its look: size, layout, theme, colors. /grim reset puts them all back "
        .. "in place.")
    Flag(category, "GRIMOIRE_TRACKER_ENABLED", "DoT tracker", "tracker", "enabled", true,
        "A row per mob you DoT, with the time left on your DoTs, Bane, Curse, and Fear.",
        RefreshTracker)
    local control = Flag(category, "GRIMOIRE_CONTROL_ENABLED", "Control bar", "control", "enabled", true,
        "Bars for the mobs you Fear or Banish, with their time left, and a Focus box above them with your "
            .. "focus's Fear. Click the Focus box to fear your focus again, or a Banish row to banish your focus "
            .. "again.", RefreshControl)
    local timers = Flag(category, "GRIMOIRE_CONTROL_PLATE_TIMERS", "Fear timers on nameplates", "control",
        "plateTimers", true,
        "A thin bar under each feared mob's nameplate that drains with your Fear's time left, so you see which "
            .. "one is about to break; click its nameplate to target it.", RefreshControl)
    timers:SetParentInitializer(control, function() return WTF.db.control.enabled end)
    Flag(category, "GRIMOIRE_SHIELD_ENABLED", "Shield display", "shield", "enabled", true,
        "A crescent or bars with your remaining absorb while a shield is on you: Shadow Ward, Sacrifice, or any "
            .. "shield. From Dyre's Shields Up.",
        function() WTF.ShieldDisplay.Refresh() end)
    Flag(category, "GRIMOIRE_STONES_SHOWN", "Stones bar", "stones", "shown", true,
        "Soulstone and Healthstone buttons: left-click uses one, right-click creates one. A button glows while "
            .. "you carry none of that stone and can make one. Changes in combat apply when combat ends.",
        RefreshStones)
    Flag(category, "GRIMOIRE_SHARDS_COUNTER", "Shard counter", "shards", "counter", true,
        "A Soul Shard icon with your shard count: red when low, green at your limit.",
        RefreshShardCounter)
    Flag(category, "GRIMOIRE_STRIP_ENABLED", "Join the small frames in one strip", "strip", "enabled", false,
        "The Stones buttons, the shard counter, the armor and demon icons and the Nightfall icon in one bar that "
            .. "moves and is styled as one in Edit Mode. Off, each is its own frame. Takes effect after a reload.")
    AddButton(layout, "Apply the strip choice", "Reload now", function()
        if InCombatLockdown() then
            WTF.Report("The interface reloads out of combat.")
            return
        end
        ReloadUI()
    end, "Reloads the interface (a short loading screen), out of combat only.")
    Heading(layout, "Macros", "Kept in your character macros, for your action bars. Off deletes them.")
    Flag(category, "GRIMOIRE_STONES_MACROS", "Stone macros", "stones", "macros", true,
        "\"! Healthstone\" and \"! Soulstone\": a press uses your best stone, or makes one when you carry none. "
            .. "A right-click always makes one.", function() WTF.ApplyStoneMacros() end)
    Flag(category, "GRIMOIRE_CONTROL_MACROS", "Control macros", "control", "macros", true,
        "\"! Fear\", \"! Banish\", \"! Seduction\", and \"! Curse\", each once you know its spell. \"! Fear\" "
            .. "makes the mob under your mouse (else your target) your focus and fears it; Shift-press it to fear "
            .. "another mob and keep your focus. \"! Banish\" and \"! Seduction\" focus the hostile mob under your "
            .. "mouse (or your target, out of combat) and cast on your focus. \"! Seduction\" appears once your "
            .. "Succubus or Incubus has learned Seduction, and casts only while one is your pet. \"! Curse\" is "
            .. "the smart curse (DoTs page). On a button whose key already holds Shift, Ctrl or Alt, a macro "
            .. "leaves out what it does with that key, so every press is the plain one.",
        function() WTF.ApplyControlMacros() end)
    AddButton(layout, "How Fear and your focus work", "Show in chat", WTF.ReportControlHelp,
        "Print in your chat frame (only you see it) how \"! Fear\", the Focus box, and \"! Banish\" use your "
            .. "focus.")
    Flag(category, "GRIMOIRE_FOCUS_MACROS", "Focus macros", "hotbar", "focusMacros", false,
        "\"! Corruption F\", \"! Immolate F\", \"! Agony F\", \"! Siphon F\" and \"! Fear F\", for the spells you "
            .. "know: each casts that spell on your focus and leaves your target alone. Their buttons show a red "
            .. "F; a DoT's glows when your focus needs it again.",
        function() WTF.ApplyFocusMacros() end)
    Flag(category, "GRIMOIRE_PREP_MACRO", "Prep macro", "hotbar", "prepMacro", false,
        "\"! Prep\" does the next missing step before a pull: summon your demon, then your armor, then a "
            .. "Healthstone, then a Soulstone, each only when you carry none and can make one. Its button glows "
            .. "while it has a step. With nothing to do, a press does nothing.", function() WTF.ApplyPrepMacro() end)
end

function WTF.InitializeOptions()
    if not HasSettingsAPI() then
        return
    end
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(TITLE)
    AddMainPage(layout)
    local cuesPage = CreateCuesPage()
    WTF.cuesPage = cuesPage
    Settings.RegisterCanvasLayoutSubcategory(category, cuesPage, CUES_TITLE)
    AddWarningsPage(category)
    AddShardsPage(category)
    AddTrackerPage(category)
    AddPredictPage(category)
    local dotsPage = CreateDotsPage()
    WTF.dotsPage = dotsPage
    Settings.RegisterCanvasLayoutSubcategory(category, dotsPage, DOTS_TITLE)
    AddDiagnosticsPage(category)
    Settings.RegisterAddOnCategory(category)
end

function WTF.OpenSettings()
    if not category then
        WTF.Report(UNAVAILABLE)
        return
    end
    -- Out of combat only, as Dyre's Toolkit opened it.
    if InCombatLockdown() then
        WTF.Report("The settings open out of combat.")
        return
    end
    Settings.OpenToCategory(category:GetID())
end
