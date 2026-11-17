# Architecture

Grimoire is plain Lua 5.1 for the WoW Forever client. No build step, no libraries, no required addons. The load order is the order in `Grimoire.toc`.

## Layers

1. **Engine** (`Engine\`): 12 files copied unmodified from Dyre's Toolkit, plus `Shim.lua`. The only change in each engine file is line 2, which points it at Grimoire's private namespace (`addon.engine`) instead of the `DyresToolkit` global. Two exceptions, every line of them marked `Grimoire`: `DotPredict.lua` carries the tick-rate channels (Wrack), and `DotTracker.lua` keeps each slot's icon by name for the recast cue. Do not edit engine files otherwise; see UPSTREAM.md.
2. **Core** (`Core.lua`, `Commands.lua`, `Layout.lua`): saved settings and their repair on load, the login sequence, slash commands, frame movers and the unlock grid.
3. **Features**: one file each. A feature file defines `WTF.Sanitize<Name>` for its settings, `WTF.Initialize<Name>` for login, and usually `WTF.Refresh<Name>` and `WTF.Report<Name>Debug`.
4. **Options** (`Options.lua`): the settings pages, built on the game's Settings API.

The code's namespace table is called `WTF` (the second value of `...` in each file). That name comes from Warlock Tools Forever and is kept so upstream diffs stay readable.

## Files

| File | Role |
|---|---|
| `Engine\Shim.lua` | creates the private engine namespace |
| `Engine\Auras.lua`, `Units.lua`, `HealthBars.lua`, `Spells.lua`, `Macros.lua`, `Announce.lua`, `ClassData.lua`, `Owners.lua` | engine helpers: aura containers, unit and nameplate lookups, health bar finding, spell indexing, macro keeping, class data. `Announce.lua`'s send function is an empty stub |
| `Engine\Control.lua`, `DotTracker.lua`, `PlateDots.lua`, `DotPredict.lua` | the four engines: Control bar, DoT tracker, nameplate dots, damage prediction |
| `Core.lua` | settings repair (`SanitizeDB`), guarded login starts, shared helpers (`IsSecret`, `MoveRestricted`, `QuietTime`, `Report`) |
| `Commands.lua` | `/grim` command table |
| `Layout.lua` | dragging, snapping, scaling of Grimoire's frames |
| `Shards.lua` | Soul Shard deletion and the counter |
| `Stones.lua` | Stones bar, stone macros, stone reminders, Healthstone trade |
| `Tracker.lua`, `Dots.lua`, `Predict.lua`, `Control.lua` | glue between Grimoire's settings and the four engines |
| `Alerts.lua` | the alert window and `WTF.Alert(key, text, level, options)` |
| `Reminders.lua` | armor and demon reminder icons and lines |
| `Threat.lua` | threat warning |
| `Pet.lua` | demon died, Enslave broke, pet taunt on autocast |
| `Procs.lua` | Nightfall sound and icon |
| `Cooldowns.lua` | cooldown-ready lines timed from your casts |
| `KeyLabels.lua` | pet bar key label size and place |
| `Shield.lua` | shield crescent (from Dyre's Shields Up) |
| `Probe.lua` | `/grim debug_restrictions`, `/grim debug_checks`, and the background diagnostics |
| `Options.lua` | settings pages |
| `Bindings.xml` | the Smart curse key binding |
| `tests\run.lua` | the mock client and every test |

## Saved data

- `GrimoireDB` (per character): all settings. Rebuilt from scratch by `WTF.SanitizeDB` on every load, so a damaged or older table cannot break the addon. A new setting needs a line there.
- `GrimoireAccountDB` (per account): `engine` (learned DoT ticks, whether focus works) and `diagnostics` (counts and the alert log).

The game writes both only at logout, `/reload` or a normal exit. Addons cannot write files.

## Login

`Core.lua` waits for `PLAYER_LOGIN`, checks that every required function exists (a mixed install fails loudly), checks the class, then starts each part through `Start(name, fn)`. A part that raises an error is reported in chat, handed to the game's error handler, listed in `WTF.startFailures`, and skipped; the others still start.

## Patterns to keep

- **Secret values.** Any combat value may be secret. Test with `WTF.IsSecret(value)` before comparing, concatenating or indexing. A secret answer means "skip", never "false".
- **Secure frames.** Buttons that cast (Stones, reminders, Control rows) may change only out of combat. Use `WTF.shared.OutOfCombat(owner, fn)` to defer.
- **Alerts.** Every line goes through `WTF.Alert`. Give it a key; per-mob keys start with a prefix and are forgotten after combat (`WTF.ForgetAlerts`).
- **Reminder lines** check `WTF.QuietTime()` and back off; icons are the standing reminder.
- **No communication.** See DEVELOPMENT.md.
