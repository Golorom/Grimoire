# Architecture

Grimoire is plain Lua 5.1 for the WoW Forever client. No build step and no required addons. One library is embedded: LibEditMode, in `Libs\LibEditMode`, unmodified. The load order is the order in `Grimoire.toc`.

## Layers

1. **Engine** (`Engine\`): 12 files copied unmodified from Dyre's Toolkit, plus `Shim.lua`. The only change in each engine file is line 2, which points it at Grimoire's private namespace (`addon.engine`) instead of the `DyresToolkit` global. Two exceptions, every line of them marked `Grimoire`: `DotPredict.lua` carries the tick-rate channels (Wrack), and `DotTracker.lua` keeps each slot's icon by name for the recast cue. Do not edit engine files otherwise; see UPSTREAM.md.
2. **Core** (`Core.lua`, `Commands.lua`, `EditMode.lua`): saved settings and their repair on load, the login sequence, slash commands, and putting every frame into the game's Edit Mode.
3. **Features**: one file each. A feature file defines `WTF.Sanitize<Name>` for its settings, `WTF.Initialize<Name>` for login, and usually `WTF.Refresh<Name>` and `WTF.Report<Name>Debug`.
4. **Options** (`Options.lua`): the settings pages, built on the game's Settings API, by topic: what each part does. How a frame looks is set in its Edit Mode dialog, registered by the frame's own file.

The code's namespace table is called `WTF` (the second value of `...` in each file). That name comes from Warlock Tools Forever and is kept so upstream diffs stay readable.

## Files

| File | Role |
|---|---|
| `Engine\Shim.lua` | creates the private engine namespace |
| `Engine\Auras.lua`, `Units.lua`, `HealthBars.lua`, `Spells.lua`, `Macros.lua`, `Announce.lua`, `ClassData.lua`, `Owners.lua` | engine helpers: aura containers, unit and nameplate lookups, health bar finding, spell indexing, macro keeping, class data. `Announce.lua`'s send function is an empty stub |
| `Engine\Control.lua`, `DotTracker.lua`, `PlateDots.lua`, `DotPredict.lua` | the four engines: Control bar, DoT tracker, nameplate dots, damage prediction |
| `Core.lua` | settings repair (`SanitizeDB`), guarded login starts, shared helpers (`IsSecret`, `MoveRestricted`, `QuietTime`, `Report`) |
| `Commands.lua` | `/grim` command table |
| `Libs\LibEditMode\` | LibEditMode (p3lim), unmodified, loaded into Grimoire's namespace by its `namespaced.lua`, so no other addon's copy is involved; Forever and retail only |
| `EditMode.lua` | registers every frame with Edit Mode (name, default place, dialog settings), shows the samples while Edit Mode is open, snaps a dropped frame (grid, screen, other frames) before LibEditMode saves it, scales a frame around its center |
| `Glow.lua` | the pulsing gold glow on buttons that want a click (stones, reminder icons), from the `Textures\Glow*.tga` pieces |
| `Hotbar.lua` | glows on the player's own action bar buttons: which button holds what (read out of combat), wants from Stones, Reminders and Recast, the Nightfall glow on Shadow Bolt through the aura engine, and the optional focus DoT macros |
| `Strip.lua` | the optional prep strip: the Stones buttons, the shard counter and the reminder icons reparented into one Edit Mode frame, laid out out of combat; on or off at login |
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
| `Shield.lua` | shield display (from Dyre's Shields Up): the absorb and timed shields as arcs on one of four sides, or flat rows |
| `scripts\build_shield_art.py` | draws the shield's arc textures (`Textures\ShieldRing*.tga`); not shipped |
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
