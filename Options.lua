local _, WTF = ...

-- The AddOn settings: a main page with one switch per module, and a subpage
-- per module for its details. Shards and Stones use Blizzard's vertical layout
-- with proxy settings that read and write GrimoireDB directly; DoTs rows you
-- drag to reorder, so that is a canvas page. Grimoire: no Announce page and no
-- pages pointing to Dyre's other AddOns.
local TITLE = "Grimoire"
local SHARDS_TITLE = "Soul Shards"
local STONES_TITLE = "Stones"
local TRACKER_TITLE = "DoT Tracker"
local DOTS_TITLE = "DoTs"
local CONTROL_TITLE = "Control"
local ALERTS_TITLE = "Alerts"
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

-- A greyed-out checkbox for a planned feature (author-approved): never on,
-- never saved.
local function ComingSoon(page, variable, name, tooltip)
    local setting = Proxy(page, variable, Settings.VarType.Boolean, name .. " (Coming soon)", false,
        function() return false end, function() end)
    local initializer = Settings.CreateCheckbox(page, setting, tooltip)
    if type(initializer.AddModifyPredicate) == "function" then
        initializer:AddModifyPredicate(function() return false end)
    end
    return initializer
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

local function Pixels(value)
    return string.format("%d px", value)
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

-- A greyed-out checkbox that only says something; never saved.
local function Notice(page, variable, name, tooltip)
    local setting = Proxy(page, variable, Settings.VarType.Boolean, name, true,
        function() return true end, function() end)
    local initializer = Settings.CreateCheckbox(page, setting, tooltip)
    if type(initializer.AddModifyPredicate) == "function" then
        initializer:AddModifyPredicate(function() return false end)
    end
    return initializer
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

local function AddControlPage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, CONTROL_TITLE)
    Heading(layout, "Fear, Banish, and your focus", table.concat(WTF.CONTROL_HELP, " "))
    -- Pinned Blizzard_SettingControls.lua:1014.
    if type(CreateSettingsButtonInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsButtonInitializer("How Fear and your focus work", "Show in chat",
            WTF.ReportControlHelp, "Say in chat how \"! Fear\", the Focus box, and \"! Banish\" use your focus.",
            true))
    end
    Flag(page, "GRIMOIRE_CONTROL_MACROS", "Keep control macros", "control", "macros", true,
        "Keep \"! Fear\", \"! Banish\", \"! Seduction\", and \"! Curse\" in your character macros for your action bars, "
            .. "each once you know its spell. \"! Fear\" makes the mob under your mouse (else your target) your "
            .. "focus and fears it; Shift-press it to fear another mob and keep your focus. The Focus box above "
            .. "the Control bar shows your focus's Fear; click it to fear your focus again. \"! Banish\" and "
            .. "\"! Seduction\" focus the hostile mob under your mouse (or your target, out of combat) and cast on "
            .. "your focus. \"! Seduction\" appears once your Succubus "
            .. "or Incubus has learned Seduction from its Grimoire, and casts only while one is your pet. \"! Curse\" "
            .. "is the smart curse (DoT Tracker page). Turning this off deletes them.", function() WTF.ApplyControlMacros() end)
    Flag(page, "GRIMOIRE_CONTROL_PLATE_TIMERS", "Fear timers on nameplates", "control", "plateTimers", true,
        "A thin bar under each feared mob's nameplate that drains with your Fear's time left, so you see which "
            .. "one is about to break; click its nameplate to target it.", RefreshControl)
    local scale = Proxy(page, "GRIMOIRE_CONTROL_SCALE", Settings.VarType.Number, "Bar size",
        WTF.DEFAULT_CONTROL_SCALE,
        function() return WTF.db.control.scale end,
        function(value)
            WTF.db.control.scale = WTF.SanitizeControlScale(value)
            RefreshControl()
        end)
    Settings.CreateSlider(page, scale,
        SliderOptions(WTF.CONTROL_SCALE_MIN, WTF.CONTROL_SCALE_MAX, WTF.CONTROL_SCALE_STEP, true),
        "How big the control bar is, in percent. A change in combat applies when combat ends.")
end

local function AddShardPage(parent)
    local page = Settings.RegisterVerticalLayoutSubcategory(parent, SHARDS_TITLE)
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
    local counterInitializer = Flag(page, "GRIMOIRE_SHARDS_COUNTER", "Show the shard counter", "shards", "counter",
        true, "A Soul Shard icon with your shard count: red when low, green at your limit. Drag it to move it.",
        RefreshShardCounter)
    local low = Proxy(page, "GRIMOIRE_SHARDS_COUNTER_LOW", Settings.VarType.Number, "Low shard warning",
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
    local lowInitializer = Settings.CreateSlider(page, low, lowOptions,
        "The counter turns red at this many Soul Shards or fewer.")
    lowInitializer:SetParentInitializer(counterInitializer, function() return WTF.db.shards.counter end)
    local counterScale = Proxy(page, "GRIMOIRE_SHARDS_COUNTER_SCALE", Settings.VarType.Number, "Shard counter size",
        WTF.DEFAULT_FRAME_SCALE,
        function() return WTF.db.shards.counterScale end,
        function(value) WTF.SetShardCounterScale(value) end)
    local counterScaleInitializer = Settings.CreateSlider(page, counterScale,
        SliderOptions(WTF.FRAME_SCALE_MIN, WTF.FRAME_SCALE_MAX, WTF.FRAME_SCALE_STEP, true),
        "How big the shard counter is, in percent. It keeps its center, and changes at once, also in combat.")
    counterScaleInitializer:SetParentInitializer(counterInitializer, function() return WTF.db.shards.counter end)
end

local function AddStonesPage(parent)
    local page = Settings.RegisterVerticalLayoutSubcategory(parent, STONES_TITLE)
    local shownInitializer = Flag(page, "GRIMOIRE_STONES_SHOWN", "Show the Stones bar", "stones", "shown", true,
        "The bar with the Soulstone and Healthstone buttons. Changes in combat apply when combat ends.",
        RefreshStones)
    local scale = Proxy(page, "GRIMOIRE_STONES_SCALE", Settings.VarType.Number, "Stones bar size",
        WTF.DEFAULT_FRAME_SCALE,
        function() return WTF.db.stones.scale end,
        function(value) WTF.SetStonesScale(value) end)
    local scaleInitializer = Settings.CreateSlider(page, scale,
        SliderOptions(WTF.FRAME_SCALE_MIN, WTF.FRAME_SCALE_MAX, WTF.FRAME_SCALE_STEP, true),
        "How big the Stones bar is, in percent. It keeps its center. A change in combat applies when combat ends.")
    scaleInitializer:SetParentInitializer(shownInitializer, function() return WTF.db.stones.shown end)
    Flag(page, "GRIMOIRE_STONES_MACROS", "Keep stone macros", "stones", "macros", true,
        "Keep \"! Healthstone\" and \"! Soulstone\" in your character macros for your action bars: "
            .. "left-click uses your best stone, right-click creates one. Turning this off deletes them.",
        function() WTF.ApplyStoneMacros() end)
    ComingSoon(page, "GRIMOIRE_STONES_SPELLSTONE", "Spellstone button",
        "A Spellstone button and macro: left-click uses it, right-click creates one.")
    ComingSoon(page, "GRIMOIRE_STONES_FIRESTONE", "Firestone button",
        "A Firestone button and macro: left-click uses it, right-click creates one.")
    Flag(page, "GRIMOIRE_STONES_REMIND_SOULSTONE", "Soulstone reminders", "stones", "remindSoulstone", true,
        "Say in chat when your Soulstone ends, and when none is up: on entering an instance, joining a group, "
            .. "or after a fight, at most every 10 minutes.")
    Flag(page, "GRIMOIRE_STONES_REMIND_HEALTHSTONE", "Healthstone reminders", "stones", "remindHealthstone", true,
        "Say in chat when you carry no Healthstone, at the same times.")
    ComingSoon(page, "GRIMOIRE_STONES_REMIND_SPELLSTONE", "Spellstone reminders",
        "Say in chat when you carry no Spellstone, at the same times.")
    ComingSoon(page, "GRIMOIRE_STONES_REMIND_FIRESTONE", "Firestone reminders",
        "Say in chat when you carry no Firestone, at the same times.")
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

-- The tracker's sizes for one theme (Core's TRACKER_SIZE_SPECS), shown only
-- while that theme is chosen: the settings list checks shown predicates again
-- on each setting change (pinned Blizzard_SettingsPanel.lua:788,
-- Blizzard_Settings.lua:96). A change rebuilds the rows, out of combat.
local function AddTrackerSizes(page, theme)
    local function ShowFor(initializer)
        if type(initializer.AddShownPredicate) == "function" then
            initializer:AddShownPredicate(function() return WTF.db.tracker.theme == theme end)
        end
    end
    local prefix = "GRIMOIRE_TRACKER_" .. theme:upper() .. "_"
    for _, spec in ipairs(WTF.TRACKER_SIZE_SPECS[theme]) do
        local setting = Proxy(page, prefix .. spec.key:upper(), Settings.VarType.Number, spec.label, spec.default,
            function() return WTF.db.tracker.sizes[theme][spec.key] end,
            function(value) WTF.SetTrackerSize(theme, spec.key, value) end)
        local options = Settings.CreateSliderOptions(spec.min, spec.max, spec.step)
        if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, spec.percent
                and function(value) return string.format("%d%%", value) end or nil)
        end
        local initializer = Settings.CreateSlider(page, setting, options,
            (spec.tooltip or ("The DoT tracker's " .. spec.label:lower() .. " in the "
                .. (theme == "bars" and "Bars" or "Compact") .. " theme."))
                .. " A change in combat applies when combat ends.")
        AddDefaultTick(initializer, spec.min, spec.max, spec.default)
        ShowFor(initializer)
    end
    local position = Proxy(page, prefix .. "NAMEPOSITION", Settings.VarType.String, "Name position",
        WTF.TRACKER_NAME_POSITIONS[theme][1].key,
        function() return WTF.db.tracker.sizes[theme].namePosition end,
        function(value) WTF.SetTrackerSize(theme, "namePosition", value) end)
    ShowFor(Settings.CreateDropdown(page, position, function()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(WTF.TRACKER_NAME_POSITIONS[theme]) do
            container:Add(choice.key, choice.label)
        end
        return container:GetData()
    end, "Where the mob's name sits in each row."))
end

-- A panel's own settings (author): its color, then its opacity.
local function AddPanelSection(page, layout, panel, colors)
    Heading(layout, panel.heading, "Settings for the DoT tracker's " .. panel.name .. " only.")
    local color = Proxy(page, "GRIMOIRE_PANEL_COLOR_" .. panel.key:upper(), Settings.VarType.String, colors.label,
        colors.color,
        function() return WTF.db.tracker.panelColors[panel.key] end,
        function(value)
            WTF.db.tracker.panelColors[panel.key] = WTF.SanitizeColor(value, colors.color)
            if WTF.ApplyPanelColors then
                WTF.ApplyPanelColors()
            end
        end)
    Settings.CreateColorSwatch(page, color, panel.key == "list"
        and "The row border and health fill of the other mobs' rows. It changes at once, also in combat."
        or "The outline and health fill of the " .. panel.name .. ". It changes at once, also in combat.")
    local setting = Proxy(page, "GRIMOIRE_TRACKER_OPACITY_" .. panel.key:upper(), Settings.VarType.Number,
        panel.label, WTF.DEFAULT_PANEL_OPACITY,
        function() return WTF.db.tracker.panelOpacity[panel.key] end,
        function(value) WTF.SetTrackerPanelOpacity(panel.key, value) end)
    local initializer = Settings.CreateSlider(page, setting,
        SliderOptions(WTF.PANEL_OPACITY_MIN, WTF.PANEL_OPACITY_MAX, 5, true),
        "How solid the " .. panel.name .. " is, rows and all, in percent. It changes at once, also in combat.")
    AddDefaultTick(initializer, WTF.PANEL_OPACITY_MIN, WTF.PANEL_OPACITY_MAX, WTF.DEFAULT_PANEL_OPACITY)
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
    .. "Smart curse key binding (Key Bindings, Warlock Tools Forever) cast it too."

local function AddCurseSection(page, layout)
    if not (WTF.SmartCurseAvailable and WTF.SmartCurseAvailable()) then
        return
    end
    Heading(layout, "Curse slot", SMART_CURSE_HELP)
    local mode = Proxy(page, "GRIMOIRE_TRACKER_CURSE_MODE", Settings.VarType.String, "Curse slot click", "last",
        function() return WTF.db.tracker.curseMode end,
        function(value) WTF.SetCurseMode(value) end)
    local modeInitializer = Settings.CreateDropdown(page, mode, function()
        local container = Settings.CreateControlTextContainer()
        container:Add("last", "Last used")
        container:Add("smart", "Smart curse")
        return container:GetData()
    end, "What a click on the target or focus row's Curse slot casts. Last used: the curse you cast last. "
        .. SMART_CURSE_HELP .. " A change in combat applies when combat ends.")
    local marker = Flag(page, "GRIMOIRE_TRACKER_CURSE_MARKER", "Show the smart curse letter", "tracker", "curseMarker",
        true, "With Smart curse, a letter on the Curse slot's icon for that mob's best curse: T Tongues, "
            .. "E Elements, W Weakness. It changes also in combat.",
        function() WTF.SetCurseMarker(WTF.db.tracker.curseMarker) end)
    marker:SetParentInitializer(modeInitializer, function() return WTF.db.tracker.curseMode == "smart" end)
end

local function AddPredictSection(page, layout)
    Heading(layout, "DoT damage prediction", "A purple block on the health bar for the damage your DoTs "
        .. "still have to deal." .. PREDICT_NEEDS)
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
    local fill = Choice("GRIMOIRE_PREDICT_FILL", "Block fill", "fill", WTF.PREDICT_FILLS, "stripes",
        "Stripes: diagonal stripes. Solid: one flat color. Bar texture: the texture of the bar it sits on. "
            .. "The same look on the target frame, nameplates, and DoT tracker rows.")
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
    for _, initializer in ipairs({enabled, plates, dies, fill, color, opacity, outline, diesPlace, diesX, diesY,
            plateDiesPlace, plateDiesX, plateDiesY}) do
        if type(initializer.AddModifyPredicate) == "function" then
            initializer:AddModifyPredicate(function() return WTF.PredictAvailable() end)
        end
    end
    plates:SetParentInitializer(enabled, function() return WTF.db.predict.enabled end)
    dies:SetParentInitializer(enabled, function() return WTF.db.predict.enabled end)
end

-- Sections (author): General (what every panel shares) first, then one per
-- panel: Target, Focus, and Others; then DoT damage prediction.
local function AddTrackerPage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, TRACKER_TITLE)
    Heading(layout, "General", "Settings that every DoT tracker panel shares, and the nameplate dots.")
    local theme = Proxy(page, "GRIMOIRE_TRACKER_THEME", Settings.VarType.String, "Theme", "compact",
        function() return WTF.db.tracker.theme end,
        function(value) WTF.SetTrackerTheme(value) end)
    Settings.CreateDropdown(page, theme, function()
        local container = Settings.CreateControlTextContainer()
        container:Add("compact", "Compact")
        container:Add("bars", "Bars")
        return container:GetData()
    end, "Compact: a row per mob with an icon per spell. Bars: a block per mob with a bar per spell you know, "
        .. "draining as its time runs out. A change in combat applies when combat ends.")
    -- The pinned rows' outline width (John, 2026-11-11; Dyre's Toolkit 2.8.0).
    local outline = Proxy(page, "GRIMOIRE_TRACKER_OUTLINE_WIDTH", Settings.VarType.Number, "Target and focus outline",
        WTF.DEFAULT_OUTLINE_WIDTH,
        function() return WTF.db.tracker.outlineWidth end,
        function(value) WTF.SetTrackerOutlineWidth(value) end)
    local outlineInitializer = Settings.CreateSlider(page, outline,
        SliderOptions(WTF.OUTLINE_WIDTH_MIN, WTF.OUTLINE_WIDTH_MAX, 1, Pixels),
        "How thick the solid outline around the target (purple) and focus (red) rows is, in pixels. 0 hides it. "
            .. "A change in combat applies when combat ends."
            .. (WTF.TrackerOutlineAvailable() and "" or " Unavailable: reinstall every Grimoire file."))
    AddDefaultTick(outlineInitializer, WTF.OUTLINE_WIDTH_MIN, WTF.OUTLINE_WIDTH_MAX, WTF.DEFAULT_OUTLINE_WIDTH)
    if type(outlineInitializer.AddModifyPredicate) == "function" then
        outlineInitializer:AddModifyPredicate(function() return WTF.TrackerOutlineAvailable() end)
    end
    local dotsInitializer = Flag(page, "GRIMOIRE_TRACKER_PLATE_DOTS", "Show DoT dots on nameplates", "tracker",
        "plateDots", false,
        "In combat, a bubble above each hostile nameplate with a dot per DoT you know: colored while it is up, "
            .. "grey while it is missing. Needs at least one DoT you know. The DoTs page chooses the dots.",
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
    local health = Proxy(page, "GRIMOIRE_TRACKER_HEALTH", Settings.VarType.Boolean, "Show mob health", false,
        function() return WTF.db.tracker.health end,
        function(value) WTF.SetTrackerHealth("health", value) end)
    local healthInitializer = Settings.CreateCheckbox(page, health,
        "Each mob's name line in the DoT tracker is its health bar, in the panel's color, also in combat. "
            .. "A change in combat applies when combat ends.")
    local healthText = Proxy(page, "GRIMOIRE_TRACKER_HEALTH_TEXT", Settings.VarType.String, "Health text", "none",
        function() return WTF.db.tracker.healthText end,
        function(value) WTF.SetTrackerHealth("healthText", value) end)
    local textInitializer = Settings.CreateDropdown(page, healthText, function()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(WTF.TRACKER_HEALTH_TEXTS) do
            container:Add(choice.key, choice.label)
        end
        return container:GetData()
    end, "The mob's health as text after its name: its number, its percent, or both.")
    textInitializer:SetParentInitializer(healthInitializer, function() return WTF.db.tracker.health end)
    AddTrackerSizes(page, "compact")
    AddTrackerSizes(page, "bars")
    -- Pinned Blizzard_SettingControls.lua:1014.
    if type(CreateSettingsButtonInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsButtonInitializer("Tracker size", "Reset size", function()
            WTF.SetTrackerSize(WTF.db.tracker.theme, nil)
        end, "Back to the theme's own sizes and name position.", true))
    end
    local colors = {}
    for _, entry in ipairs(WTF.TRACKER_PANEL_COLORS) do
        colors[entry.key] = entry
    end
    for _, panel in ipairs(WTF.TRACKER_PANELS) do
        AddPanelSection(page, layout, panel, colors[panel.key])
    end
    AddCurseSection(page, layout)
    AddPredictSection(page, layout)
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
local PLATES_OFF_TIP = "Turn on Show DoT dots on nameplates on the DoT Tracker page to choose the dots."

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

-- Grimoire 0.2: the alert window, reminders, combat warnings, and the shield.
local function Seconds(value)
    return string.format("%d s", value)
end

local function Plain(value)
    return tostring(value)
end

local function Slider(page, variable, name, default, getValue, setValue, minValue, maxValue, step, format, tooltip)
    local setting = Proxy(page, variable, Settings.VarType.Number, name, default, getValue, setValue)
    return Settings.CreateSlider(page, setting, SliderOptions(minValue, maxValue, step, format), tooltip)
end

local function ApplyProcSounds()
    if WTF.ApplyProcSounds then
        WTF.ApplyProcSounds()
    end
end

local function AddAlertsPage(parent)
    local page, layout = Settings.RegisterVerticalLayoutSubcategory(parent, ALERTS_TITLE)
    Heading(layout, "Alert window", "Short warnings for you only. A line shows at once, stays, then fades. "
        .. "Nothing is sent to other players.")
    if type(CreateSettingsButtonInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsButtonInitializer("Test the alerts", "Show test alerts",
            WTF.TestAlerts, "Three sample lines, one of each color, with a sound. Same as /grim test.", true))
    end
    Flag(page, "GRIMOIRE_ALERTS_ENABLED", "Show the alert window", "alerts", "enabled", true,
        "Off: alerts go to chat instead.", function() WTF.RefreshAlerts() end)
    Flag(page, "GRIMOIRE_ALERTS_CHAT", "Also print alerts in chat", "alerts", "chat", false,
        "Each alert also as a chat line. Chat addons that filter by addon (Chattynator) can put them in a tab.")
    Flag(page, "GRIMOIRE_ALERTS_SOUNDS", "Play alert sounds", "alerts", "sounds", true,
        "The game sounds of the threat, demon, cooldown, and Nightfall alerts.", ApplyProcSounds)
    Slider(page, "GRIMOIRE_ALERTS_HOLD", "Hold time", WTF.DEFAULT_ALERT_HOLD,
        function() return WTF.db.alerts.hold end,
        function(value)
            WTF.db.alerts.hold = WTF.SanitizeWhole(value, WTF.ALERT_HOLD_MIN, WTF.ALERT_HOLD_MAX, WTF.DEFAULT_ALERT_HOLD)
            WTF.RefreshAlerts()
        end, WTF.ALERT_HOLD_MIN, WTF.ALERT_HOLD_MAX, 1, Seconds, "How long a line stays before it fades.")
    Slider(page, "GRIMOIRE_ALERTS_FADE", "Fade time", WTF.DEFAULT_ALERT_FADE,
        function() return WTF.db.alerts.fade end,
        function(value)
            WTF.db.alerts.fade = WTF.SanitizeWhole(value, WTF.ALERT_FADE_MIN, WTF.ALERT_FADE_MAX, WTF.DEFAULT_ALERT_FADE)
            WTF.RefreshAlerts()
        end, WTF.ALERT_FADE_MIN, WTF.ALERT_FADE_MAX, 1, Seconds, "How long a line takes to fade out.")
    Slider(page, "GRIMOIRE_ALERTS_LINES", "Lines", WTF.DEFAULT_ALERT_LINES,
        function() return WTF.db.alerts.lines end,
        function(value)
            WTF.db.alerts.lines = WTF.SanitizeWhole(value, WTF.ALERT_LINES_MIN, WTF.ALERT_LINES_MAX,
                WTF.DEFAULT_ALERT_LINES)
            WTF.RefreshAlerts()
        end, WTF.ALERT_LINES_MIN, WTF.ALERT_LINES_MAX, 1, Plain, "At most this many lines at once.")
    Slider(page, "GRIMOIRE_ALERTS_BACKGROUND", "Background opacity", WTF.DEFAULT_ALERT_BACKGROUND,
        function() return WTF.db.alerts.background end,
        function(value)
            WTF.db.alerts.background = WTF.SanitizeWhole(value, WTF.ALERT_BACKGROUND_MIN, WTF.ALERT_BACKGROUND_MAX,
                WTF.DEFAULT_ALERT_BACKGROUND)
            WTF.RefreshAlerts()
        end, WTF.ALERT_BACKGROUND_MIN, WTF.ALERT_BACKGROUND_MAX, 5, true,
        "The dark panel behind the lines. 25% is 75% transparent; 0 shows the text alone.")
    Slider(page, "GRIMOIRE_ALERTS_SCALE", "Window size", WTF.DEFAULT_FRAME_SCALE,
        function() return WTF.db.alerts.scale end,
        function(value) WTF.SetAlertsScale(value) end,
        WTF.FRAME_SCALE_MIN, WTF.FRAME_SCALE_MAX, WTF.FRAME_SCALE_STEP, true, "How big the alert text is.")
    Heading(layout, "Reminders", "Out of combat. Each has an icon you click to cast.")
    Flag(page, "GRIMOIRE_REMIND_ARMOR", "Demon Armor reminder", "reminders", "armor", true,
        "An icon and a line while neither Demon Armor nor Demon Skin is on you, and a line a minute before it "
            .. "runs out. Click the icon to cast it.", function() WTF.RefreshReminders() end)
    Flag(page, "GRIMOIRE_REMIND_DEMON", "Demon reminder", "reminders", "demon", true,
        "An icon while you have no demon out (hidden while mounted), and a line after combat. Click it to summon "
            .. "your last demon.", function() WTF.RefreshReminders() end)
    Heading(layout, "In combat")
    Flag(page, "GRIMOIRE_THREAT_ENABLED", "Threat warning", "threat", "enabled", true,
        "A red line and a sound when a mob your Voidwalker or a tank held turns to you. Mobs you pull "
            .. "yourself never warn.")
    Flag(page, "GRIMOIRE_THREAT_RISK", "Warn before you pull", "threat", "risk", true,
        "A yellow line and a softer sound when you pass the one holding the mob but it has not turned yet.")
    Flag(page, "GRIMOIRE_THREAT_SOUNDS", "Threat sounds", "threat", "sounds", true,
        "The sounds of the two threat lines.")
    Flag(page, "GRIMOIRE_PET_DIED", "Demon died", "pet", "died", true,
        "A red line and a sound when your demon dies in combat, and when Enslave Demon breaks.")
    Flag(page, "GRIMOIRE_PET_LOW", "Demon low health", "pet", "low", true,
        "A line when your demon drops below the share below, in combat. Only where the game lets addons read "
            .. "pet health in combat (/grim debug_checks).")
    Slider(page, "GRIMOIRE_PET_LOW_SHARE", "Demon low at", WTF.DEFAULT_PET_LOW,
        function() return WTF.db.pet.lowShare end,
        function(value)
            WTF.db.pet.lowShare = WTF.SanitizeWhole(value, WTF.PET_LOW_MIN, WTF.PET_LOW_MAX, WTF.DEFAULT_PET_LOW)
        end, WTF.PET_LOW_MIN, WTF.PET_LOW_MAX, 5, true, "The health share for the line above.")
    Flag(page, "GRIMOIRE_PROCS_SOUND", "Nightfall sound", "procs", "sound", true,
        "The game plays the Imp's spell chirp the moment Nightfall (Shadow Trance) lands, also in combat.",
        ApplyProcSounds)
    Flag(page, "GRIMOIRE_PROCS_ICON", "Nightfall icon", "procs", "icon", true,
        "A Shadow Trance icon with its time left while it is up. Unlock frames to move it.",
        function() WTF.RefreshProcs() end)
    Flag(page, "GRIMOIRE_COOLDOWNS_ENABLED", "Cooldown alerts", "cooldowns", "enabled", true,
        "A line just before a chosen spell is ready again, timed from your cast.")
    Flag(page, "GRIMOIRE_COOLDOWNS_SOUND", "Cooldown sound", "cooldowns", "sound", true,
        "The game's talent-ready sound with each cooldown line.")
    for _, def in ipairs(WTF.COOLDOWN_SPELLS or {}) do
        local setting = Proxy(page, "GRIMOIRE_COOLDOWN_" .. def.key:upper(), Settings.VarType.Boolean,
            "  " .. def.label, def.on,
            function() return WTF.db.cooldowns.spells[def.key] end,
            function(value) WTF.db.cooldowns.spells[def.key] = value == true end)
        Settings.CreateCheckbox(page, setting, "A line when " .. def.label .. " is ready again.")
    end
    Heading(layout, "Shield", "A crescent beside your character with your remaining absorb: Shadow Ward, "
        .. "Sacrifice, or any shield on you. From Dyre's Shields Up.")
    Flag(page, "GRIMOIRE_SHIELD_ENABLED", "Shield display", "shield", "enabled", true,
        "Shows while a shield is on you. Unlock frames to move it.",
        function() WTF.ShieldDisplay.Refresh() end)
    Flag(page, "GRIMOIRE_SHIELD_NUMBER", "Show the absorb number", "shield", "number", true,
        "The amount left, under the crescent.", function() WTF.ShieldDisplay.Refresh() end)
end

function WTF.InitializeOptions()
    if not HasSettingsAPI() then
        return
    end
    category = Settings.RegisterVerticalLayoutCategory(TITLE)
    Flag(category, "GRIMOIRE_SHARDS_ENABLED", "Soul Shard management", "shards", "enabled", true,
        "Delete Soul Shards that Drain Soul creates above your limit. Shards you move into your bags are never deleted.")
    Flag(category, "GRIMOIRE_STONES_ENABLED", "Stones", "stones", "enabled", true,
        "A bar with Soulstone and Healthstone buttons: left-click uses one, right-click creates one.",
        RefreshStones)
    Flag(category, "GRIMOIRE_TRACKER_ENABLED", "DoT tracker", "tracker", "enabled", true,
        "A row per mob you DoT, with the time left on your DoTs, Bane, Curse, and Fear.",
        RefreshTracker)
    Flag(category, "GRIMOIRE_CONTROL_ENABLED", "Control bar", "control", "enabled", true,
        "Bars for the mobs you Fear or Banish, with their time left, and a Focus box above them with your "
            .. "focus's Fear. Click the Focus box to fear your focus again, or a Banish row to banish your focus "
            .. "again.", RefreshControl)
    do
        local unlocked = Proxy(category, "GRIMOIRE_UNLOCKED", Settings.VarType.Boolean, "Unlock frames to move them",
            false,
            function() return not WTF.db.locked end,
            function(value)
                if value == true then
                    WTF.Unlock()
                else
                    WTF.Lock()
                end
            end)
        Settings.CreateCheckbox(category, unlocked,
            "Outline the Stones bar and the shard counter, and show sample DoT tracker rows, so you can drag "
                .. "them; untick to lock them again. /grim unlock and /grim lock do the same, and /grim reset moves "
                .. "them back.")
        local grid = Proxy(category, "GRIMOIRE_GRID", Settings.VarType.Boolean, "Show a grid while unlocked", true,
            function() return WTF.db.grid end,
            function(value)
                WTF.db.grid = value == true
                WTF.RefreshGrid()
            end)
        Settings.CreateCheckbox(category, grid, "While frames are unlocked, draw a faint grid over the screen "
            .. "with the center lines in red, so you can line frames up.")
    end
    AddShardPage(category)
    AddStonesPage(category)
    AddTrackerPage(category)
    local dotsPage = CreateDotsPage()
    WTF.dotsPage = dotsPage
    Settings.RegisterCanvasLayoutSubcategory(category, dotsPage, DOTS_TITLE)
    AddControlPage(category)
    AddAlertsPage(category)
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
