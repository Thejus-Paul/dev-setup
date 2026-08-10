# dev-setup

One shell script that takes a fresh Mac to a working one: Homebrew, 38 formulae
and casks, mise-managed runtimes, System Settings, app preferences, and the shell
hooks that make the whole thing work in a new terminal.

## Run it

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/Thejus-Paul/dev-setup/main/setup.sh)
```

Or from a clone:

```sh
git clone https://github.com/Thejus-Paul/dev-setup.git && cd dev-setup && ./setup.sh
```

Process substitution, not `curl … | bash`. The pipe form puts the script on stdin,
where `brew install` can swallow un-executed script bytes and gum finds no
terminal to draw on.

It asks for your password once at the start, then runs unattended.

## Rerunning is the point

Every step is idempotent, so rerunning is how an existing machine gets topped up.
Steps keep going after a failure and the summary table at the end is what to read
— a provisioning run that halts on its ninth package leaves you worse off than
one that finishes and names the two things that broke.

Three questions get asked, each covering a change you might not want on a machine
you are already happy with: the package bundle, the System Settings, and the app
preferences. Answering no to one does not answer no to the others.

## What it installs

| group | packages |
| --- | --- |
| Shell and search | `fd` `ripgrep` `fzf` `fff-mcp` `zoxide` `mise` `gh` `lazygit` `nvim` `topgrade` `rtk` `mole` |
| Windows and desktop | `amethyst` `loop` `monitorcontrol` `mos` `raycast` `meetingbar` |
| Security | `keepassxc` `gnupg` `lulu` `knockknock` `oversight` `taskexplorer` |
| Apps | `warp` `helium-browser` `obsidian` `slack` `zoom` `iina` `localsend` |
| Dev dependencies | `postgresql` `redis` `libyaml` `readline` `zlib` `shared-mime-info` |
| Font | `font-fira-code-nerd-font` |

`fd`, `ripgrep` and `fff-mcp` are one search set rather than three overlapping
tools: `fd` matches file names, `ripgrep` searches contents and returns every
match, `fff-mcp` ranks either by frecency and truncates. `fzf` is the interactive
front end the first two feed.

`amethyst` and `loop` are both window managers and both stay. `loop` resizes the
one window you are dragging; `amethyst` retiles every window on the space by
itself.

## What it configures

**Runtimes** — Ruby and Node through mise, not rbenv or nvm.

**Shell** — activation lines for mise, zoxide and fzf are appended to `.zshrc`,
matched loosely so a hand-edited variant is left alone rather than duplicated.

**System Settings** — a dozen values read off a machine tuned by hand: Dock
autohide on the left edge, Finder in list view, dark mode, tap to click, no
`.DS_Store` on network or USB volumes, firewall with stealth mode, two-minute
display sleep on battery.

**App preferences** — for OverSight, KnockKnock, Loop and Raycast, through
`defaults`. A key ships only if it was a deliberate choice *and* still means
something on a different machine, which is why MonitorControl and TaskExplorer
write nothing: one keys brightness by monitor serial, the other keeps a first-run
flag and a debug toggle.

**Warp** — the exception. Warp keeps its configuration in `~/.warp`, and its
plist is a mirror it writes but does not read back, already drifted from the real
settings on five of six keys. So its files are tracked in `config/warp/` and
installed directly, never overwriting one that is already there.

**MCP and hooks** — `fff-mcp` is registered with Claude Code and `rtk init` is
run, because both are inert after a brew install on their own.

## What it cannot do

Accessibility, Screen Recording and Full Disk Access live in the TCC database,
which SIP protects and only an Apple-internal tool writes. Amethyst, Loop,
MonitorControl and Raycast do nothing until Accessibility is ticked; OverSight
needs Screen Recording plus the microphone and camera; KnockKnock and
TaskExplorer want Full Disk Access. LuLu is not TCC but has the same shape: it
stays inert as a firewall until its system extension is approved.

The run ends by naming them and opening the Accessibility pane, rather than
pretending they are handled.

## Tests

```sh
./setup.sh --self-test
```

Covers the parts that are easy to get wrong and expensive to discover late: that
`append_once` and `install_config` never duplicate or clobber, that a failing step
is recorded rather than fatal, that the gum gate stays off without a terminal,
that `confirm` never blocks when nobody is there to answer, that both settings
blocks parse, and that every preference domain maps back to a package the bundle
installs.

Touches nothing on the machine running it.

## Output

`gum` draws the run when there is a terminal to draw on and gets out of the way
when there is not. To force plain output and capture everything, pipe it:

```sh
./setup.sh | tee setup.log
```

The gate checks stdin and stdout both. `curl | bash` leaves stdout a terminal
while bash reads the script from stdin, so a stdout-only check would start a TUI
with no terminal to read from.
