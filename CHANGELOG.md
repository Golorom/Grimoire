# Changelog

## 0.2.3 (2026-11-17)

Added
- Recast cue: a DoT's slot on the tracker pulses when it is time to start casting it again, that is when its time left is the spell's cast time plus a lead time (0.5 s; DoT Tracker page). An instant DoT pulses one lead time before it ends. Hidden while you cast that spell at that mob. The time left is Predict's own clock from your casts, since addon code cannot read the tracker's timers; the cast time is the game's, so talents count. `/grim debug_recast` shows the numbers.
- Diagnostics: one combat log line's shape (letters and digits masked), a probe of the refresh carry-over function, whether the client has the game's own rotation helper (`C_AssistedCombat`) and whether its next spell reads, and room for a function's whole usage error.

## 0.2.2 (2026-11-17)

Added
- Predict: groundwork for Wrack. While you channel it, your Corruption, Siphon Life and Bane of Agony on that mob are counted as ticking twice as fast, with the skipped time staying skipped. The engine takes a list of such channels (`WTF.PREDICT_CHANNELS` in `Predict.lua`), so another one is a line of data. Setting: DoT Tracker page, "Faster ticks while channeling Wrack" (on). `/grim debug_predict` shows the channel and this session's counts; the diagnostics count starts, ticks in rhythm and misses, to check the model once the talent is taken. Built from the hotfix notes; not yet seen in game.
- README: recommended addons.

## 0.2.1 (2026-11-17)

After an audit against one evening of in-game data.

Changed
- Alert window: centered lines, no backdrop by default. A panel saved under the first look is dropped once; the opacity setting stays.
- Threat warning: alone, one yellow silent line when a held mob turns to you and no "about to pull" line; in a group, as before (yellow before, red with a sound when it turns).
- Armor and demon reminder lines back off: at once, then after 2, 5, then every 15 minutes. No reminder lines (stones included) while dead, on a flight path or resting. The icons still show.
- Login line shows the fork's own author; version is bumped with each build.

Added
- Pet taunt warning (from Dyre's Toolkit): your demon's taunt on autocast in a group where you are not the tank.
- Dungeon shard trim (from Warlock Tools Forever 1.8.1).
- Summon Incubus in the demon reminder and the demon warnings.
- Each part starts on its own at login: one that fails is reported and the others still start.
- Diagnostics round two: combat log lines counted as secret, scrambled or plain; a readable `false` keeps its sample; once per login, which planned-for functions the client has. Old counts start over.
- Tests: a source scan for send calls; reminders while dead, flying or resting; guarded starts.
- README rewritten; `docs/`.

Removed
- "Demon low health" alert and its slider: a demon's health is secret to addon code on Forever, in and out of combat, so it could never fire.
- Four "Coming soon" Spellstone and Firestone placeholders.
- Dead debug functions (`DebugDeleteShard`, `ReportClickDebug`).

Fixed
- Stone reminder help said "Say in chat"; the lines go to the alert window.
- Per-mob alert throttles were never forgotten.
- Engine `Control.lua` synced to Dyre's Toolkit 2.10.0.

## 0.2.0 and fixes (2026-11-15 to 2026-11-16)

- Alert window, reminders, threat warning, demon warnings, Nightfall sound and icon, cooldown alerts, shield display, Compact tracker by default.
- Shield mirror setting; Nightfall icon draggable; pet bar key labels keep their size and place.
- Background diagnostics with a settings page.

## 0.1.0 (2026-11-15)

- Fork of Warlock Tools Forever 1.8.0 with Dyre's Toolkit 2.9.2 engines bundled. Announcements, whispers, emotes, raid markers and Toolkit integration removed. Renamed to Grimoire, `/grim`.
