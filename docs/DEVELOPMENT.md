# Development

For people and for coding agents alike. Read ARCHITECTURE.md and FOREVER-API.md first.

## Rules

1. **Nothing is sent to other players.** No `SendChatMessage`, addon messages, emotes, raid markers, invites or mail, in any file, engine included. Printing to the player's own chat frame (`WTF.Report`) and the alert window are fine. The Healthstone trade in `Stones.lua` is the one allowed path, and it runs only on the player's click. The test "source scan" enforces this; do not weaken it.
2. **Strip, don't rewrite.** Code that came from upstream keeps its structure and names. Mark a Grimoire change with a `-- Grimoire:` comment or a version note, so the next upstream diff shows what is ours.
3. **No required dependencies.** No libraries unless the owner approves one. (LibEditMode is approved for the Edit Mode work; it must be embedded unmodified, and its name must not appear in the addon's title.)
4. **Never compare a secret value.** See ARCHITECTURE.md.
5. **Keep the MIT notice** in `LICENSE`.
6. **Engine files are upstream's.** Change behavior in the glue files, or patch upstream; see UPSTREAM.md.

## Tests

```
lua5.1 tests/run.lua
```

Run from the repository root. Every test must pass before an install. The suite runs the real addon files against a mock client in `tests/run.lua`; it cannot prove behavior in the game, and its last line says so. When the game contradicts the mock, fix the mock (FOREVER-API.md is the record).

Static checks:

```
for f in *.lua Engine/*.lua; do luac5.1 -p "$f"; done
luacheck *.lua --std lua51 --no-max-line-length --ignore 113 112 111 143
```

`fixture(options)` builds a logged-in Warlock. Useful options: `db` (saved settings), `accountDB`, `group` ("party" or "raid"), `known` (spell IDs), `units`, `beforeLogin(state, env)`.

## Adding a feature

1. A new file needs a line in `Grimoire.toc` (and then a client restart to load). Prefer an existing file for small things.
2. Settings: a `WTF.Sanitize<Name>` function, called from `WTF.SanitizeDB` in `Core.lua`.
3. Start: add the function to `REQUIRED_NAMESPACE` and a `Start("Name", WTF.Initialize<Name>)` line in `Core.lua`.
4. Settings page: `Flag(...)` or a slider in `Options.lua`. Say in the tooltip what it does and when it stays quiet.
5. A `/grim debug_<name>` command that only prints.
6. Tests for the behavior, including the secret-value case.

## Installing a build

The installed copy lives in `World of Warcraft\_forever_\Interface\AddOns\Grimoire`. Copy the changed files there, then compare checksums of the installed files against the build: a stale copy has silently survived an install before. Tell the player whether a `/reload` or a restart is needed.

## Reading what the game recorded

After a logout or `/reload`:

- Errors: `WTF\Account\<account>\SavedVariables\!BugGrabber.lua`. Look for stacks that run through `Grimoire`.
- Diagnostics and the alert log: `WTF\Account\<account>\SavedVariables\Grimoire.lua`, table `GrimoireAccountDB.diagnostics`. In game: `/grim debug_log`.
- Settings: `WTF\Account\<account>\<realm>\<character>\SavedVariables\Grimoire.lua`.

## Versions

`## Version:` in `Grimoire.toc` is the version the login line prints. Bump it with every installed build and add an entry to `CHANGELOG.md`.

## Releases

The repository has two workflows. Tests run on every push. A release is made by pushing a tag:

1. Set `## Version:` in `Grimoire.toc` and add the `## <version>` section to `CHANGELOG.md`.
2. Commit, tag `v<version>`, push the tag.
3. The Release workflow runs the tests, checks that the tag matches the TOC, builds `Grimoire-v<version>.zip` (the addon in a `Grimoire` folder, without `tests`, `docs` and `.github`) and publishes it as a GitHub release with that changelog section as its notes.
