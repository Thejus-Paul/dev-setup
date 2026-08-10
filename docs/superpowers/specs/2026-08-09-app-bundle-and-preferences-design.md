# Add the window managers and the Objective-See tools, and configure them

Date: 2026-08-09
Status: implemented

## Goal

Install `amethyst`, `knockknock`, `oversight`, `raycast` and `taskexplorer`, and
carry over the preferences this machine actually runs them with. `loop`,
`monitorcontrol` and `slack` were named in the same request and were already in
`BREW_PACKAGES`; they are unchanged.

The interesting half is not the install. It is deciding which of these apps have
a configuration worth writing down, and admitting which part of the setup no
script can do at all.

## What gets installed

Five names join `BREW_PACKAGES`, in the alphabetical order the list already
keeps, taking it from 31 packages to 36. All five are casks in `homebrew-core`,
so none needs a tap.

Two comment paragraphs go in above the list, in the style of the ones already
there. The first explains why `amethyst` and `loop` both stay: Loop resizes the
single window you drag, Amethyst retiles every window on the space on its own.
Neither does the other's job. The second groups `knockknock`, `oversight` and
`taskexplorer` as Objective-See's, which report what a machine persists, records
and runs rather than blocking any of it.

## What gets configured

A new `APP_SETTINGS` string sits beside `MACOS_SETTINGS` and runs through the
same `step`, behind its own `confirm`. Fourteen `defaults write` lines across four
domains:

| domain | what it sets |
| --- | --- |
| `com.objective-see.oversight` | start at login, no menu-bar icon |
| `com.objective-see.KnockKnock` | start at login, no VirusTotal lookups, hide Apple-trusted items |
| `com.MrKai77.Loop` | shift/command/control trigger, side-dependent trigger key, follow the cursor's screen, snapping off, resize animation off, Rose Pine icon |
| `com.raycast.macos` | compact window mode, follow system appearance, no hyper-key icon |

Every value was read off this machine, which is where `MACOS_SETTINGS` came from
too, then filtered: a key stays only if it is a deliberate choice *and* means
something on a different box.

### Why three of the new apps write nothing

That filter is the whole design, so the exclusions are the argument for it.

**MonitorControl** keeps brightness and DDC ceilings keyed by monitor serial
(`value16(LGHDRQHD778923445@2)`). On another machine those keys address displays
that do not exist.

**TaskExplorer** has two keys: a first-run flag and
`NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints`, an AppKit debug
toggle. Propagating the second would be copying a mistake.

**Amethyst** has a preferences file but no application — it is a leftover from
an install that is gone. Its 165 keys are the ones Amethyst ships with, plus
`focus-follows-mouse`. Baking a stale file would be guessing at intent, so the
cask installs and configures nothing.

### The ⌘Space question, answered no

Handing ⌘Space to Raycast means disabling Spotlight's hotkey through
`com.apple.symbolichotkeys` key 64. This machine has no override for key 64,
so Spotlight still owns the shortcut here. Writing that override would invent a
setting rather than copy one, which is the opposite of how `MACOS_SETTINGS` was
built. Left alone.

### The ordering hazard

`defaults write` against a running app is not merely ignored — it is reverted.
The app holds its preferences in memory and writes them back over yours when it
quits. The fresh box this script targets has launched none of these apps, so the
writes land. A rerun on a live machine needs the app quit first. This is a
comment in the source, not a `killall`: terminating a window manager partway
through a setup run is worse than a lost write.

## Warp, and why `defaults` is the wrong tool for it

Warp was very nearly configured the same way as the four above, with a pair of
`defaults write` lines for the font — closing what looked like an old gap, since
`font-fira-code-nerd-font` was already in the bundle with nothing selecting the
font it installed.

That would have been wrong. Warp keeps its configuration in
`~/.warp/settings.toml`; the `dev.warp.Warp-Stable` plist is a mirror it writes
and does not read back as config. Warp's own documentation confirms it, listing
that domain only under uninstall, as leftover state to `defaults delete`. The
local plist carries `SettingsFileMigrationComplete = true`.

The plist being *written* is what makes it a trap: it looks authoritative and
reads cleanly. On this machine it had already drifted from the real settings on
five of six overlapping keys — theme (`Tokyo-night` against `dracula`), all three
vertical-tab keys, and the SSH tmux wrapper. Only the font agreed, and only
because it had not changed since the migration.

So Warp's settings travel as the files Warp actually reads. `config/warp/`
carries `settings.toml` and `keybindings.yaml` into the repo, and a new
`install_config` helper puts them in `~/.warp/`. Both files are portable as-is:
no absolute paths, no tokens, and per Warp's docs a settings file contains only
deviations from default, so there is nothing to filter.

`install_config` follows `append_once`'s rule — an existing file is left alone,
because a config edited since outranks the snapshot recorded here — and is called
directly rather than through `step`, for `append_once`'s reason too: `step` runs
its argument under `sh -c`, where a function from this file does not exist.

It reads from `SCRIPT_DIR` when the run has a checkout and falls back to fetching
from `RAW_URL`, which is what the documented `bash <(curl …)` invocation needs.
No detection is required between the two: under that form `$0` is a file
descriptor, `SCRIPT_DIR` resolves to `/dev/fd`, no file is found, and the fetch
path is taken. A failed fetch deletes the file first — `curl -o` creates it
before it knows the request failed, and an empty `settings.toml` reads to Warp as
"configured, with nothing in it".

The calls are unguarded, unlike the `append_once` ones. A `.zshrc` line for a
missing tool breaks every new terminal; a settings file for a missing Warp is
just a file, already correct whenever Warp arrives.

## The one package that needed a command, not a preference

An audit of the other thirty packages turned up exactly one more inert install:
`rtk`. Its whole mechanism is a Claude Code hook that rewrites commands, and the
hook reads its instructions out of `~/.claude`, where a brew install puts
nothing.

So `rtk init --global` joins `main` next to the `fff-mcp` step it resembles, with
one difference. The `fff` step needs a `claude mcp get` probe because `mcp add`
fails on a name that already exists, which would turn every rerun into a FAILED
row. `rtk init` needs no probe: it appends a single `@RTK.md` line to
`CLAUDE.md`, leaves everything already in that file untouched, and no-ops on a
second run — all three confirmed against a throwaway `HOME`. It does not create
`~/.claude` and fails outright when that directory is missing, which is why the
guard tests for the directory rather than for `claude` on `PATH`.

Three other packages were checked and deliberately got nothing. `redis` does not
appear in `brew services list` at all, so it has never run as a service here.
`postgresql` is started under brew, but `.zshrc`'s `start_postgres` drives a
*mise*-installed postgres instead — a duplicate to resolve, not a step to add.
`gnupg` has no secret keys, no `commit.gpgsign` and no `GPG_TTY`, so there is no
configuration to carry over.

## What no script can do

Accessibility, Screen Recording and Full Disk Access live in the TCC database.
SIP protects it, and the only tool that writes it is Apple-internal. Amethyst,
Loop, MonitorControl and Raycast are inert until Accessibility is ticked;
OverSight needs Screen Recording plus the microphone and camera; KnockKnock and
TaskExplorer want Full Disk Access.

So the run ends by naming them. After `summary`, a `warn`-level `note` lists the
grants, and the Accessibility pane opens — but only under `[ -t 1 ]`, on the same
reasoning as `detect_gum`: a piped or CI run has nobody to tick a checkbox, and
System Settings stealing focus from a background run is a bug. The `open` is
wrapped in `|| true` so a failure does not become `main`'s exit status.

## Testing

`self_test` gains two checks beside the existing `MACOS_SETTINGS` one.

`sh -n -c "$APP_SETTINGS"` parses the block without running it. `APP_SETTINGS`
embeds a double-quoted string inside a single-quoted block, which is the kind of
quoting that breaks long after anyone is looking at it.

The second check parses the domain out of every `defaults` line and maps it back
to a package in `BREW_PACKAGES`, failing on either an unmapped domain or a
missing package. Without it, an upstream rename or a package dropped from the
bundle leaves a `defaults write` that reports success against nothing —
`defaults` creates the domain whether or not an app will ever read it.

`install_config` gets two more: that it leaves an existing file alone, and that
it copies the tracked file when the destination is empty. The second is guarded
on the checkout existing, so running `--self-test` through `bash <(curl …)` skips
it rather than reaching for the network mid-test.
