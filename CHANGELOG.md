# Changelog

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
