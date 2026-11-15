# Grimoire 0.2.0

Personal fork of Warlock Tools Forever 1.8.0 by Dyre, with the engines of Dyre's Toolkit 2.9.2 by Dyre in `Engine\`. Both are MIT licensed, Copyright (c) 2026 John Bedworth; see LICENSE.

Sources:
- https://github.com/jbedworth/WarlockToolsForever (1.8.0, commit aec6409)
- https://github.com/jbedworth/DyresToolkit (2.9.2, commit e8b0094)
- https://github.com/jbedworth/DyresShieldsUp (1.2.1, commit 8940229): Shield.lua and Textures\ShieldArc*.tga, unchanged
- Threat, cooldown and Nightfall logic follow Dyre's Toolkit Threat.lua and Dyre's Buff Reminders (MIT); the code in Threat.lua, Cooldowns.lua and Procs.lua is Grimoire's own

## Added in 0.2.0

- Alerts.lua: alert window (slim, fades), /grim test, Alerts settings page.
- Reminders.lua: Demon Armor/Skin and demon icons with click to cast, reminder lines.
- Threat.lua: DPS threat warning from UnitThreatSituation.
- Pet.lua: demon died, Enslave Demon broke, demon low health (where readable).
- Procs.lua: Nightfall sound (game-played aura sound) and icon.
- Cooldowns.lua: cooldown ready lines.
- Shield.lua: Dyre's Shields Up shield display.
- Stone reminders, Soulstone end and low shards go to the alert window.
- DoT tracker: Compact and smaller by default; WTF's untouched defaults move once.
- Raid marker settings dropped. /grim debug_checks.

## Changes from upstream

Engine (Toolkit files):
- Every file: one added second line, `ns = ns.engine`, so the engines run in a private namespace and create no `DyresToolkit` global.
- Shim.lua: new, sets up that namespace.
- HealthBars.lua: Grimoire's own claims are allowed; texture path points to Grimoire.
- Announce.lua: `SendChat` sends nothing.

Removed:
- Announce.lua and every group message, whisper and emote (summon, Soulstone, Healthstone trade, stone creation, Fear, Banish, Enslave, Howl).
- Raid markers in "! Banish" and the other macros.
- Dyre's Toolkit layout mode, settings home and the pages and login notes about Dyre's other AddOns.
- Commands debug_delete, debug_click, debug_announce, debug_emote.

Renamed:
- Folder and title Grimoire, SavedVariables GrimoireDB and GrimoireAccountDB, slash commands /grim and /grimoire, frame names, settings names, key binding header.

Defaults:
- The chat line for each deleted Soul Shard is off.

Internal Lua names stay WTF's, so upstream changes can still be compared line by line.
