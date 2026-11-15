local addonName, addon = ...

-- Grimoire: the engine files in this folder are Dyre's Toolkit 2.9.2's
-- (Auras, Units, HealthBars, Spells, Macros, Announce, ClassData, Owners,
-- Control, DotTracker, PlateDots, DotPredict), MIT, by John Bedworth. In the
-- Toolkit they run in the Toolkit's namespace, on the global DyresToolkit.
-- Here each file's second line switches to this private table instead, so
-- nothing is global and an installed Dyre's Toolkit never clashes with it.
--
-- engine.toolkit  what the engines call DyresToolkit (Core.lua: WTF.shared)
-- engine.db       the engines' one saved table (focusWorks, ticks,
--                 ticksImported): GrimoireAccountDB.engine, set by Core.lua
--                 at ADDON_LOADED; a fresh table until then
-- engine.debug    the Toolkit's debug mode: failing frame hooks said in chat
local engine = {toolkit = {}, db = {}, debug = false}
addon.engine = engine
engine.ADDON = addonName

function engine.Report(message)
    DEFAULT_CHAT_FRAME:AddMessage("Grimoire: " .. tostring(message))
end
