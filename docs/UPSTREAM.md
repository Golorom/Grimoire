# Upstream

Grimoire stands on four MIT projects by Dyre (John Bedworth). None of them is required at run time.

| Upstream | Forked at | Last checked | What Grimoire took |
|---|---|---|---|
| [Warlock Tools Forever](https://github.com/jbedworth/WarlockToolsForever) | 1.8.0 (aec6409) | 1.8.1 (342aa7a), 2026-11-17 | the base: Core, Commands, Layout, Shards, Stones, Tracker, Dots, Predict, Control, Options, Probe, tests |
| [Dyre's Toolkit](https://github.com/jbedworth/DyresToolkit) | 2.9.2 (e8b0094) | 2.10.0 (443b872), 2026-11-17 | 12 engine files in `Engine\`; the Threat and PetTaunt ideas, cut down |
| [Dyre's Buff Reminders](https://github.com/jbedworth/DyresBuffReminders) | 1.8.0 | 1.9.0 (e211d64), 2026-11-16 | the patterns behind Reminders, Procs and Cooldowns |
| [Dyre's Shields Up](https://github.com/jbedworth/DyresShieldsUp) | 8940229 | unchanged, 2026-11-16 | `Shield.lua` and the crescent textures |

## Ported since the fork

- WTF 1.8.1: shards gained in a dungeon above the limit are trimmed as you leave it (0.2.1).
- Toolkit 2.9.3 to 2.10.0: `Engine\Control.lua` (0.2.1). The other 11 engine files did not change.
- Toolkit 2.9.0 PetTaunt: the pet taunt warning, as an alert line instead of a message box and chat line (0.2.1).

## Grimoire's own changes to engine files

One engine file differs from upstream by more than line 2:

- `Engine\DotPredict.lua` (0.2.2): tick-rate channels, for Wrack. `spec.channels` and `spec.onRate` are new; every changed or added line carries a `Grimoire` comment, and the main block sits between `SentKey` and `OnSent` under the heading "Grimoire: tick-rate channels". When pulling an upstream change to this file, apply the upstream diff first, then check that the marked lines are still in place (`grep -n Grimoire Engine/DotPredict.lua` lists 15). If Dyre's Toolkit gains its own Wrack handling, drop this patch and use upstream's.

## Not taken, on purpose

Announcements, whispers, emotes and raid markers; the Toolkit's settings home, widgets, profiles and minimap button; support for other classes; Dyre's Sounds (not open-licensed).

## Pulling an upstream change

Engine files:

1. `git diff <old tag> <new tag> -- <File>.lua` in a Toolkit clone.
2. `patch -p1 Engine/<File>.lua < that.diff` in Grimoire.
3. Check: the engine file must equal upstream's except for line 2 (`ns = ns.engine ...`), and for `DotPredict.lua` the lines marked `Grimoire` (see above).
4. Run the tests.

WTF files: the same with `patch -p1 --fuzz=3`; names and line numbers differ a little, the structure does not. Port upstream's tests for the change too. Then read the diff for anything that sends chat, and remove it.

Record the new "last checked" commit in the table above.
