# Grimoire 0.1.0

Personal fork of Warlock Tools Forever 1.8.0 by Dyre, with the engines of Dyre's Toolkit 2.9.2 by Dyre in `Engine\`. Both are MIT licensed, Copyright (c) 2026 John Bedworth; see LICENSE.

Sources:
- https://github.com/jbedworth/WarlockToolsForever (1.8.0, commit aec6409)
- https://github.com/jbedworth/DyresToolkit (2.9.2, commit e8b0094)

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
