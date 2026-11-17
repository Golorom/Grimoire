# Grimoire

Personal Warlock tools for World of Warcraft: Forever (interface 16001). Slash command: `/grim`.

Grimoire is a fork of [Warlock Tools Forever](https://github.com/jbedworth/WarlockToolsForever) (WTF) 1.8.0 by Dyre (John Bedworth), with the engines of [Dyre's Toolkit](https://github.com/jbedworth/DyresToolkit) bundled inside it. It was made for one player's own use. If you want a maintained, general Warlock addon, use Warlock Tools Forever.

## The one rule

Grimoire never sends anything to other players by itself: no chat, whispers, emotes, raid markers or addon messages. Everything it shows is for you only. A test scans the source for send calls on every run.

One action reaches another player, and only on your click: a left-click on the Healthstone button with a friendly player targeted opens a trade and places a Healthstone in it. You press Trade yourself.

## What it does

- **Soul Shards.** Deletes shards that Drain Soul or Shadowburn create above your limit (your soul bag's size, or a number you set). Shards you had, bought or moved in are never deleted. A counter shows how many you carry.
- **Stones.** A bar with Soulstone and Healthstone buttons: left-click uses, right-click creates. Reminders when none is up.
- **DoT tracker.** A row per mob you have DoTs on, with the time left on your Curse, Bane, Corruption, Immolate, Siphon Life and Fear. Optional dots under nameplates.
- **Predict.** Shows the damage your DoTs will still do on the target's health bar, and DIES when they will finish the mob.
- **Control bar.** Timers for the mobs you Fear or Banish, with `! Fear`, `! Banish`, `! Seduction` and `! Curse` macros kept up to date in your macro list.
- **Alert window.** Short lines in a window of their own: centered text, no backdrop by default.
- **Reminders.** Click-to-cast icons for a missing Demon Armor or Demon Skin and a missing demon. Their lines back off (at once, then 2, 5, then every 15 minutes) and stay quiet while you are dead, on a flight path or resting.
- **Threat warning.** A line when a mob your Voidwalker or a tank held turns to you: red with a sound in a group, yellow and silent alone.
- **Demon warnings.** Your demon died; Enslave Demon broke; your demon's taunt is on autocast in a group.
- **Nightfall.** A sound and an icon when Shadow Trance procs.
- **Cooldown alerts.** A line just before a chosen spell is ready, timed from your own cast.
- **Shield display.** A crescent beside your character for Sacrifice and other absorbs, on either side.
- **Pet bar key labels.** Keeps the pet bar's key labels at the size and place of your other bars' labels.
- **Diagnostics.** While you play, counts whether the game lets addon code read the values Grimoire's features need. Counts only, kept on your computer.

## How it differs from Warlock Tools Forever

| | Warlock Tools Forever 1.8 | Grimoire |
|---|---|---|
| Announcements, whispers, emotes, raid markers | yes, optional | removed |
| Needs Dyre's Toolkit installed | yes, for the tracker, Predict and Control bar | no: the 12 engine files are bundled in `Engine\` under a private namespace |
| Alert window, reminders, threat, demon, Nightfall and cooldown alerts, shield display | in Dyre's other addons (Buff Reminders, Shields Up, Toolkit) | folded in, rewritten to send nothing |
| Background diagnostics, pet bar key labels | no | yes |
| Settings home | inside Dyre's Toolkit's panel | its own page: Options, AddOns, Grimoire |
| Other classes, other Dyre addons | supported by the Toolkit | Warlock only |

Internal Lua names are kept as in WTF (the namespace is still called `WTF` in the code), so upstream changes can be compared and ported line by line. See [docs/UPSTREAM.md](docs/UPSTREAM.md).

## Install

Copy the `Grimoire` folder into `World of Warcraft\_forever_\Interface\AddOns\`. Restart the game after adding or removing files; `/reload` is enough after changing existing ones.

No other addon is required. BugSack with BugGrabber is useful for catching errors.

## Commands

| Command | Does |
|---|---|
| `/grim` | opens the settings |
| `/grim test` | shows three sample alerts |
| `/grim unlock`, `/grim lock` | lets you drag Grimoire's frames, then fixes them |
| `/grim reset` | moves the frames back to their default places |
| `/grim shards`, `/grim stones` | prints the current state in your chat frame |
| `/grim debug_log` | prints the diagnostics; `debug_log_save` writes them to disk (a reload), `debug_log_reset` clears them |
| `/grim debug_...` | read-only diagnostics per part; any unknown word, such as `/grim help`, lists them |

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): the files and how they fit together.
- [docs/FOREVER-API.md](docs/FOREVER-API.md): what addon code can and cannot read on this client, measured in game.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): rules, tests, installing a build, reading errors.
- [docs/UPSTREAM.md](docs/UPSTREAM.md): what came from where, and how to pull upstream changes.
- [CHANGELOG.md](CHANGELOG.md).

## License and credits

MIT, see [LICENSE](LICENSE). The original work is copyright (c) 2026 John Bedworth (Dyre): Warlock Tools Forever, Dyre's Toolkit, Dyre's Buff Reminders and Dyre's Shields Up, all MIT. Grimoire's changes are released under the same license. Dyre's Sounds is not included: it is not open-licensed.

Grimoire is not Dyre's addon. Please do not report its problems to him.
