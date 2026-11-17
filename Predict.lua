local _, WTF = ...

-- DoT damage prediction (John, 1.4.0; on Forever since Toolkit 2.6.0): a purple
-- block on the health bar of your target, of each hostile nameplate, and of
-- each DoT tracker row with mob health on, the size of the damage your DoTs
-- still have to deal, and "DIES" when that is at least the mob's health. It
-- reads the combat log; where that is restricted (Forever), the Toolkit's
-- hidden-ticks path reads your casts and UNIT_COMBAT, and the predictor's
-- `hidden` is true. With neither (Forever with a Toolkit before 2.6), nothing
-- is made and the settings are greyed. Since
-- 1.5.0 the engine is Dyre's Toolkit's (DotPredict.lua's CreateDotPredictor,
-- 2.5.0, moved from here; its header holds the rules), a HealthBars damage
-- source at priority 10 (Dyre's Debuff Tracker draws above it). WTF keeps its
-- settings (db.predict, repaired in Core), its colors, and its Options; its
-- learned ticks (WarlockToolsForeverAccountDB.ticks) are copied once to the
-- Toolkit's one store for every Dyre's AddOn.

local PREDICT_PRIORITY = 10

-- Grimoire: channels that change how fast your DoTs tick while you channel
-- them (Engine\DotPredict.lua, "Tick-rate channels"). Wrack (Forever hotfix
-- 2026-11-10): Corruption, Siphon Life and Bane of Agony tick twice as fast,
-- and the time skipped stays skipped. The spell is matched by ID (Dyre's
-- Toolkit's tests name it) and by name. Not checked in client yet: `scope`
-- assumes only the mob you channel on is affected ("all" would be every mob),
-- and `longest` is only the safety stop if the game sends no channel end.
WTF.PREDICT_CHANNELS = {
    {key = "wrack", label = "Wrack", ids = {1316697}, names = {"Wrack"}, rate = 2,
        families = {"corruption", "siphon", "agony"}, scope = "target", longest = 15},
}

-- What the predictor saw, counted in the diagnostics (counts only), so the
-- first sessions with Wrack show whether the model fits: many "tick" and few
-- "miss" means the faster rhythm matched.
local function OnRate(what, key)
    if type(WTF.NoteDiagnostic) == "function" then
        WTF.NoteDiagnostic("predict.rate." .. key .. "." .. what)
    end
end

local predict = {available = false}

local function Color()
    for _, preset in ipairs(WTF.PREDICT_COLORS) do
        if preset.key == WTF.db.predict.color then
            return preset.color
        end
    end
end

function WTF.PredictAvailable()
    return predict.available
end

function WTF.PredictedDamage(guid)
    if not predict.available then
        return 0
    end
    return WTF.predictor:PredictedDamage(guid)
end

-- Settings changed.
function WTF.RefreshPredict()
    if predict.available then
        WTF.predictor:Refresh()
    end
end

-- Before the DoT tracker (Core), whose rows draw the predictor's damage.
function WTF.InitializePredict()
    local predictor = WTF.shared.CreateDotPredictor({
        addon = "Grimoire",
        priority = PREDICT_PRIORITY,
        class = "WARLOCK",
        store = WTF.db.predict,
        color = Color,
        channels = WTF.PREDICT_CHANNELS,
        onRate = OnRate,
    })
    if not predictor then
        return
    end
    WTF.predictor = predictor
    predict.available = true
end

-- /grim debug_predict: each mob's DoTs, ticks, the average tick and where it
-- came from (learned, saved, or guessed), and the damage to come.
function WTF.ReportPredictDebug()
    if not predict.available then
        WTF.Report("DoT prediction: off on this client (the combat log and the hidden-ticks path are both closed).")
        return
    end
    for index, line in ipairs(WTF.predictor:DebugLines()) do
        WTF.Report(index == 1 and ("DoT prediction: " .. line) or line)
    end
end
