# Upstream

Grimoire stands on four MIT projects by Dyre (John Bedworth). None of them is required at run time.

| Upstream | Forked at | Last checked | What Grimoire took |
|---|---|---|---|
| [Warlock Tools Forever](https://github.com/jbedworth/WarlockToolsForever) | 1.8.0 (aec6409) | 1.8.1 (342aa7a), 2026-11-17 | the base: Core, Commands, Layout (replaced in 0.3.0), Shards, Stones, Tracker, Dots, Predict, Control, Options, Probe, tests |
| [Dyre's Toolkit](https://github.com/jbedworth/DyresToolkit) | 2.9.2 (e8b0094) | 2.10.0 (443b872), 2026-11-17 | 12 engine files in `Engine\`; the Threat and PetTaunt ideas, cut down |
| [Dyre's Buff Reminders](https://github.com/jbedworth/DyresBuffReminders) | 1.8.0 | 1.9.0 (e211d64), 2026-11-16 | the patterns behind Reminders, Procs and Cooldowns |
| [Dyre's Shields Up](https://github.com/jbedworth/DyresShieldsUp) | 8940229 | unchanged, 2026-11-16 | `Shield.lua` and the crescent textures |

## Ported since the fork

- WTF 1.8.1: shards gained in a dungeon above the limit are trimmed as you leave it (0.2.1).
- Toolkit 2.9.3 to 2.10.0: `Engine\Control.lua` (0.2.1). The other 11 engine files did not change.
- Toolkit 2.9.0 PetTaunt: the pet taunt warning, as an alert line instead of a message box and chat line (0.2.1).

## Grimoire's own changes to engine files

Two engine files differ from upstream by more than line 2:

- `Engine\DotPredict.lua` (0.2.2): tick-rate channels, for Wrack. `spec.channels` and `spec.onRate` are new; every changed or added line carries a `Grimoire` comment, and the main block sits between `SentKey` and `OnSent` under the heading "Grimoire: tick-rate channels". When pulling an upstream change to this file, apply the upstream diff first, then check that the marked lines are still in place (`grep -n Grimoire Engine/DotPredict.lua` lists 15). If Dyre's Toolkit gains its own Wrack handling, drop this patch and use upstream's.
- `Engine\DotTracker.lua` (0.2.3): four lines in `CreateRow` that keep each slot's own icon in `row.slotIcons[slot.key]`, marked `Grimoire`, so the recast cue can lay its mark over a slot without touching the row.

## Replaced by Grimoire's own

The rework of Dyre's front starts here; each replaced file no longer takes upstream changes.

- `Layout.lua` (WTF's unlock with magnetic snapping, the grid and the gold outlines): replaced by `EditMode.lua` and the game's Edit Mode in 0.3.0. Upstream changes to WTF's `Layout.lua` and to its unlock code in `Core.lua` no longer apply.

## LibEditMode

`Libs\LibEditMode` is [LibEditMode](https://github.com/p3lim-wow/LibEditMode) by p3lim, at commit adfa353 (MINOR 19), copied unmodified. Its license is not MIT: it allows embedding in an addon only unmodified, with files removed at most; `tests`, `utils` and the repository files were left out. To update it, replace the folder with the new version's runtime files (`LibEditMode.lua`, `namespaced.lua`, `pools.lua`, `embed.xml`, `widgets\`, `LICENSE.txt`, `README.md`) as they are, and check that the TOC still loads `namespaced.lua` before `embed.xml`.

## Not taken, on purpose

Announcements, whispers, emotes and raid markers; the Toolkit's settings home, widgets, profiles and minimap button; support for other classes; Dyre's Sounds (not open-licensed).

## Pulling an upstream change

Engine files:

1. `git diff <old tag> <new tag> -- <File>.lua` in a Toolkit clone.
2. `patch -p1 Engine/<File>.lua < that.diff` in Grimoire.
3. Check: the engine file must equal upstream's except for line 2 (`ns = ns.engine ...`), and for `DotPredict.lua` and `DotTracker.lua` the lines marked `Grimoire` (see above).
4. Run the tests.

WTF files: the same with `patch -p1 --fuzz=3`; names and line numbers differ a little, the structure does not. Port upstream's tests for the change too. Then read the diff for anything that sends chat, and remove it.

Record the new "last checked" commit in the table above.
