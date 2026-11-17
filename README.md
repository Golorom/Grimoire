# Grimoire

Personal Warlock tools for World of Warcraft: Forever (interface 16001). Slash command: `/grim`.

Grimoire is a fork of [Warlock Tools Forever](https://github.com/jbedworth/WarlockToolsForever) (WTF) 1.8.0 by Dyre (John Bedworth), with the engines of [Dyre's Toolkit](https://github.com/jbedworth/DyresToolkit) bundled inside it. It was made for one player's own use. If you want a maintained, general Warlock addon, use Warlock Tools Forever.

## The one rule

Grimoire never sends anything to other players by itself: no chat, whispers, emotes, raid markers or addon messages. Everything it shows is for you only. A test scans the source for send calls on every run.

One action reaches another player, and only on your click: a left-click on the Healthstone button with a friendly player targeted opens a trade and places a Healthstone in it. You press Trade yourself.

## What it does

- **Soul Shards.** Deletes shards that Drain Soul or Shadowburn create above your limit (your soul bag's size, or a number you set). Shards you had, bought or moved in are never deleted. A counter shows how many you carry.
- **Stones.** A bar with Soulstone and Healthstone buttons: left-click uses, right-click creates. A button glows when you carry none of that stone and can make one. Row or column, size, spacing and background are set in Edit Mode. Reminders when none is up.
- **DoT tracker.** A row per mob you have DoTs on, with the time left on your Curse, Bane, Corruption, Immolate, Siphon Life and Fear. Optional dots under nameplates.
- **Recast cue.** A DoT's slot on the tracker pulses when it is time to start casting it again: when its time left is the spell's cast time plus a lead time you set, so the new one lands as the old one ends.
- **Predict.** Shows the damage your DoTs will still do on the target's health bar, and DIES when they will finish the mob. While you channel Wrack it counts the faster ticks (built ahead of the talent; not yet checked in game).
- **Control bar.** Timers for the mobs you Fear or Banish, with `! Fear`, `! Banish`, `! Seduction` and `! Curse` macros kept up to date in your macro list.
- **Alert window.** Short lines in a window of their own: centered text, no backdrop by default.
- **Reminders.** Glowing click-to-cast icons for a missing Demon Armor or Demon Skin and a missing demon. Their lines back off (at once, then 2, 5, then every 15 minutes) and stay quiet while you are dead, on a flight path or resting.
- **Threat warning.** A line when a mob your Voidwalker or a tank held turns to you: red with a sound in a group, yellow and silent alone.
- **Demon warnings.** Your demon died; Enslave Demon broke; your demon's taunt is on autocast in a group.
- **Nightfall.** A sound and an icon when Shadow Trance procs.
- **Cooldown alerts.** A line just before a chosen spell is ready, timed from your own cast.
- **Shield display.** A gold-rimmed arc for Sacrifice and other absorbs, to the right, left, top or bottom of your character, or flat rows. Set in Edit Mode.
- **Pet bar key labels.** Keeps the pet bar's key labels at the size and place of your other bars' labels.
- **Edit Mode.** Every Grimoire frame moves in the game's own Edit Mode, under its own name, and snaps like the game's frames.
- **Diagnostics.** While you play, counts whether the game lets addon code read the values Grimoire's features need. Counts only, kept on your computer.

## How it differs from Warlock Tools Forever

| | Warlock Tools Forever 1.8 | Grimoire |
|---|---|---|
| Announcements, whispers, emotes, raid markers | yes, optional | removed |
| Needs Dyre's Toolkit installed | yes, for the tracker, Predict and Control bar | no: the 12 engine files are bundled in `Engine\` under a private namespace |
| Alert window, reminders, threat, demon, Nightfall and cooldown alerts, shield display | in Dyre's other addons (Buff Reminders, Shields Up, Toolkit) | folded in, rewritten to send nothing |
| Background diagnostics, pet bar key labels | no | yes |
| Settings home | inside Dyre's Toolkit's panel | its own page: Options, AddOns, Grimoire |
| Moving frames | its own unlock, with magnetic snapping | the game's Edit Mode |
| Other classes, other Dyre addons | supported by the Toolkit | Warlock only |

Internal Lua names are kept as in WTF (the namespace is still called `WTF` in the code), so upstream changes can be compared and ported line by line. See [docs/UPSTREAM.md](docs/UPSTREAM.md).

## Install

Copy the `Grimoire` folder into `World of Warcraft\_forever_\Interface\AddOns\`. Restart the game after adding or removing files; `/reload` is enough after changing existing ones.

No other addon is required.

## Recommended addons

None of these is needed; Grimoire runs alone. They are the ones it was built and tested beside.

| Addon | Why |
|---|---|
| [BugSack](https://www.curseforge.com/wow/addons/bugsack) with [!BugGrabber](https://www.curseforge.com/wow/addons/bug-grabber) | Catches Lua errors with the file and line, and keeps them between sessions. This is how a clash with another addon, or a part of Grimoire that failed to start, gets found. Install both. BugSack's "Fatality" sound plays on any addon's error, not only Grimoire's; it can be muted in BugSack's settings. |
| The game's own Cooldown Manager | Shows your cooldowns and tracked buffs. Grimoire leaves those to it and only adds what it lacks. |
| The game's own Damage Meter | Predict learns each DoT's tick size from it after a fight. With it off, Predict keeps guessing from the spell's rank and your spell power. |
| Enemy nameplates (a game setting) | Predict and the DoT dots draw on them, and they let Grimoire tell mobs apart in a fight. |

Questie, Chattynator, Baganator, BetterVendorPrice, ProfessionMaster, TradeBoard and TrainerSpells were installed during testing, and BugGrabber recorded no Grimoire error beside them. If BugSack shows an error that names `Grimoire` in its path, it is Grimoire's; an error naming another addon's folder is that addon's, even if it appeared after Grimoire was installed.

When reporting a problem, include the BugSack text and the output of `/grim debug_log`.

## Commands

| Command | Does |
|---|---|
| `/grim` | opens the settings |
| `/grim test` | shows three sample alerts |
| `/grim reset` | moves the frames back to their default places |
| `/grim shards`, `/grim stones` | prints the current state in your chat frame |
| `/grim debug_log` | prints the diagnostics; `debug_log_save` writes them to disk (a reload), `debug_log_reset` clears them |
| `/grim debug_...` | read-only diagnostics per part; any unknown word, such as `/grim help`, lists them |

Frames move in the game's Edit Mode: press Esc, then Edit Mode.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): the files and how they fit together.
- [docs/FOREVER-API.md](docs/FOREVER-API.md): what addon code can and cannot read on this client, measured in game.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): rules, tests, installing a build, reading errors.
- [docs/UPSTREAM.md](docs/UPSTREAM.md): what came from where, and how to pull upstream changes.
- [CHANGELOG.md](CHANGELOG.md).

## License and credits

MIT, see [LICENSE](LICENSE). The original work is copyright (c) 2026 John Bedworth (Dyre): Warlock Tools Forever, Dyre's Toolkit, Dyre's Buff Reminders and Dyre's Shields Up, all MIT. Grimoire's changes are released under the same license. Dyre's Sounds is not included: it is not open-licensed.

`Libs\LibEditMode` is [LibEditMode](https://github.com/p3lim-wow/LibEditMode) by p3lim (Adrian L Lange), embedded unmodified under its own license (`Libs\LibEditMode\LICENSE.txt`), which is not MIT.

Grimoire is not Dyre's addon. Please do not report its problems to him.
