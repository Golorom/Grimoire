# What addon code can read on WoW Forever

Forever's addon API is retail Midnight's (its change list is a difference from 12.1.5), with Midnight's restrictions active: combat values can be "secret". Code may hold a secret value and hand it to the game's own widgets, but may not compare it, do arithmetic on it, or branch on it.

This file records what was measured in the game, not what documentation says. Update it when the diagnostics show something new.

## Measured

Client 1.60.1 build 70938, open world only, 2026-11-16, by Grimoire's background diagnostics (`Probe.lua`). Nothing here has been measured inside a dungeon yet; restrictions there can be tighter.

| Value | In combat | Out of combat |
|---|---|---|
| Your own casts (`UNIT_SPELLCAST_SUCCEEDED` spell ID) | readable | readable |
| `UnitThreatSituation("player", mob)` | readable | nil (not on a threat list) |
| `UnitDetailedThreatSituation` scaled percent | readable | nil |
| `UnitThreatSituation("pet", mob)` | readable | nil |
| `UnitGUID("target")` | readable | readable |
| `C_Spell.GetSpellInfo(id).castTime` | readable | readable |
| `C_Spell.GetSpellCooldown(id)` | secret | readable |
| `UnitHealth("pet")` | secret | secret |
| Aura reads on any unit (`C_UnitAuras.*`) | refused | readable |
| Combat log events | not delivered | not delivered |
| `UnitHealthPercent("pet", ...)` | secret | secret |
| Combat log chat tab lines | plain strings, no KString marker (22 lines, 2026-11-17); content not yet looked at | same |

The game's own predicates (`C_Secrets.ShouldAurasBeSecret`, `ShouldSpellCooldownBeSecret`, `ShouldUnitThreatStateBeSecret`) agreed with the samples every time.

Only the `Combat` addon restriction was ever active in the open world.

Also confirmed in game on 2026-11-15: saved variables write and load; mob GUIDs read in combat; Predict learns DoT ticks from the built-in damage meter after combat.

## Consequences

- Anything timed from your own casts is on solid ground: DoT timers, cooldown timing, shard creation windows.
- Real cooldown state in combat is closed. The game's Cooldown Manager and its alerts know it; addon code does not.
- A demon's health cannot drive a line or a sound. It can drive a display through the game (see below).
- Auras in combat can only be shown through the game's aura containers and aura sounds (`C_UnitAuras.AddAuraSound`), as the DoT tracker and the Nightfall cue do.
- The combat log tab: Blizzard documents its lines as scrambled KStrings, but the lines sampled here were plain strings. Whether they carry amounts is being checked (`combatlog.shape` in the diagnostics keeps one line's shape, letters and digits masked). Do not build on it until that is read.

## Present in the client, not yet used

All of these exist on client 1.60.1 (probed 2026-11-17, `api.*` facts in `/grim debug_log`), as do `C_CooldownViewer`, `C_DamageMeter`, `C_CombatAudioAlert`, `C_UnitAuras.AddAuraSound` and `C_EditMode.GetLayouts`. `Enum.UnitAuraSoundTrigger` has Added, ApplicationsIncreased and Removed.

- `UnitHealthPercent(unit, usePredicted, curve)` with a curve from `C_CurveUtil`: turns a health percent into a number or color inside the game; the result can go to `SetAlpha` or a color setter. A "demon low" icon would use this.
- `C_VoiceChat.SpeakText`: text to speech, heard only by you.
- `C_Item.GetWeaponEnchantInfo` (Forever): temporary weapon enchants, for a Firestone or Spellstone reminder. It needs an argument (called with none it raised a usage error); the next diagnostics keep the whole usage line.
- `C_UnitAuras.GetRefreshCarryOverDuration` (Forever): time a recast would carry over. Arguments unknown; probed with a spell ID (`carryOver.spell`). The recast cue would add this time to its lead.
- `Enum.UnitAuraSoundTrigger`: which aura sound triggers exist besides Added.

## Client rules that bit us

- A new file in the TOC, a new texture, or a TOC change needs a full client restart. `/reload` is enough for changed Lua files.
- `Frame:SetPropagateKeyboardInput` cannot be called in combat.
- `DeleteCursorItem` needs a hardware event (a key press or click) and deletes one item per event.
- A status bar handed to the aura engine becomes forbidden to addon code.
- `C_Item.DeleteItem` (Forever) is for Blizzard's code only.

## Sources

- Warcraft Wiki: [Patch 1.60.1 API changes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes), [Patch 12.0.0 API changes notes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes/notes), [Secret aspects](https://warcraft.wiki.gg/wiki/Secret_aspects).
