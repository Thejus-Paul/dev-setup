# Give `setup.sh` a Charm-style TUI with gum

Date: 2026-08-09
Status: approved, not yet implemented

## Goal

Make `setup.sh` readable while it runs. Today it emits a wall of Homebrew and
Cargo output with `ok:` / `FAILED:` lines buried in it. After this change the
run shows a banner, one spinner per step, and a result table at the end.

Mostly cosmetic. One prompt was added later, deliberately — see "Asking
before the payload". Everything else is presentation, and the script still
runs unattended whenever there is nobody to answer.

A second, smaller change rides along: the Rust toolchain and the
`cargo install` step are removed, and the tools they delivered move to
Homebrew. It is separable and can ship as its own commit, but it is specified
here because it changes the step list the TUI renders. See "Dropping Rust".

## Audience

The target is a **freshly formatted Mac** with nothing installed. Every
decision below is judged against that machine, not against any existing
workstation. Current-machine state is drift, not requirements.

## What we take from Charm

[charm.land](https://charm.land/) publishes two kinds of thing: Go libraries
(Bubble Tea, Lip Gloss, Huh, Bubbles, Log, Glamour, Harmonica) and standalone
CLI binaries (gum, glow, vhs, freeze, skate, mods, crush).

Only **gum** is usable here. The Go libraries would require rewriting
`setup.sh` in Go, which repeats the Rust implementation this repo just deleted
in favour of a single shell file. The other binaries do not serve a
provisioner.

So: gum, or nothing. Everything below is gum.

## Non-goals

- No Go or Rust rewrite. One shell file stays one shell file.
- No `gum choose`. Package selection stays in the script, not in a picker.
  (`gum confirm` was originally excluded here too, and was added later — see
  "Asking before the payload".)
- No VHS demo GIF. That is a README asset, tracked separately if wanted.
- No new files besides this spec. No repo-level dependency on gum.

## Constraints

1. **gum is absent at line 1.** `setup.sh` provisions a machine with nothing
   installed. Every gum call must degrade to plain `echo`.
2. **The script will be curl-bootstrapped.** The repo goes public later, and
   the documented entry point becomes a one-liner. gum must not break under it.
3. **Existing behaviour is preserved.** `set -uo pipefail`, steps continue
   after a failure, every step idempotent, `--self-test` still works.

## Design

### Bootstrap order

gum is installed by the script, so the run has an unstyled prologue:

1. Plain-text banner, then sudo priming (see below). No gum yet.
2. The Homebrew bootstrap. Still plain — roughly one minute.
3. `brew install gum` as its own step, immediately after `brew shellenv`.
4. Re-evaluate the gum gate. Everything after this point is styled.
5. The remaining steps — the `brew install` bundle and mise — land after the
   flip, so the slowest work gets the spinner.

`gum` is installed on its own line rather than added to `BREW_PACKAGES`,
because the big install is the step we want it to decorate.

Fetching a gum binary from GitHub releases to style the prologue was
considered and rejected. It buys a spinner on one step and costs roughly
twenty lines: `releases/latest/download/gum_Darwin_arm64.tar.gz` returns 404
because assets are version-named (`gum_0.17.0_Darwin_arm64.tar.gz`), so the
tag has to be resolved through the GitHub API at 60 unauthenticated requests
per hour, plus arch detection, checksum verification outside Homebrew's, a
temp dir, PATH munging, and cleanup — after which gum is installed a second
time through brew anyway. The plain branch has to exist regardless, so using
it for the prologue costs nothing.

### Sudo priming

`gum spin` hides the wrapped command's output, and that includes sudo password
prompts. Two steps prompt for one:

- The Homebrew bootstrap needs sudo to create and chown `/opt/homebrew`.
  `NONINTERACTIVE=1` suppresses the "Press RETURN" confirmation, not the
  password.
- `brew install $BREW_PACKAGES` includes the `zoom` cask. `setup.sh` already
  says so on line 17: `# Zoom installation requires a password.`

Spinning either of those without priming means the user watches a spinner
while sudo waits silently on stdin. So the script asks once, up front, where
the prompt is visible and labelled:

```sh
echo "==> Asking for your password once, so the rest of the run is unattended."
if sudo -v; then
  while true; do sudo -n true; sleep 60; done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
fi
```

The keepalive is load-bearing, not decoration. macOS caches a sudo timestamp
for five minutes; Homebrew plus 23 formulae plus casks runs far longer, so
without it `zoom` would prompt ten minutes in, behind a spinner. `sudo -n true`
refreshes without ever prompting, so a lapsed timestamp fails quietly instead
of hanging.

The PID is captured explicitly rather than killed via the `%1` job spec, since
job control is off in non-interactive shells. The trap is installed only
inside the success branch, so `set -u` cannot trip over an unset variable when
sudo is unavailable.

If `sudo -v` fails — not a sudoer, wrong password, no TTY in CI — the script
continues. Homebrew will then fail and report FAILED in the summary, which
matches the existing "keep going, read the summary" behaviour.

This does mean the script holds a live sudo timestamp for the whole run. That
is the trade being made deliberately: the alternative is an invisible prompt
mid-run, and the script needs root for Homebrew and the casks either way.

### The gate

```sh
GUM=0
detect_gum() {
  if command -v gum >/dev/null && [ -t 0 ] && [ -t 1 ]; then GUM=1; fi
}
```

Checked once at start and again after step 2. Written as an `if` rather than
an `&&` chain so the function does not return non-zero when gum is absent.

`command -v gum` is the condition the gate exists for. The prologue runs
before gum is installed, and `brew install gum` can itself fail; without the
check every step in that window returns 127 and reports FAILED.

Both `-t 0` and `-t 1` are checked. gum's own docs: "if Gum is run without a
terminal (non-TTY), interactive commands will exit with an error." `gum spin`
runs a Bubble Tea program and is the command this protects — `gum style` and
`gum table --print` are not interactive, and Lip Gloss drops colour on its own
when it does not detect a terminal. Under `curl … | bash` stdout is still a
terminal while stdin is the pipe, so a stdout-only check would enable gum in
exactly the case where `gum spin` has no terminal to read from.

There is deliberately no `NO_COLOR` condition. gum reads `NO_COLOR` itself, so
adding it here would give one variable two meanings — gum's "no colour" versus
ours "no gum at all". The plain-output escape hatch is already served by
`-t 1`.

### Presentation functions

Four functions, each one gum branch and one plain branch.

| Function | gum branch | Plain branch |
| --- | --- | --- |
| `banner` | `gum style --border rounded --padding "1 2" --align center` | `echo` |
| `step LABEL CMD` | `gum spin --title LABEL --show-error -- sh -c CMD` | current `run()` body |
| `note MSG LEVEL` | `gum log -l "$LEVEL"` | `echo` |
| `summary` | `gum table --print` | aligned `printf` |

`step` replaces `run()`. `gum spin` propagates the wrapped command's exit
code, so the existing ok/FAILED branch is unchanged; `step` additionally
appends `LABEL,ok` or `LABEL,FAILED` to a `RESULTS` array.

`summary` pipes `STEP,RESULT` plus `RESULTS` into `gum table --print`.
`--print` renders statically instead of opening the interactive row selector.

Labels are fixed strings chosen by the caller, so no CSV escaping is needed.
Keep commas out of labels.

### Output change

`--show-error` suppresses a command's output when it succeeds and prints it
when it fails. This is the point of the change: Homebrew's progress chatter
disappears, failures still show their real error.

The cost is that a succeed-with-warnings goes unseen. The escape hatch already
exists at no extra code: redirecting or piping the run — `./setup.sh | tee
setup.log` — fails the `-t 1` check, turns the gate off, and restores today's
full output. Install caveats are the common casualty, so the closing "Done."
line points at `brew info postgresql redis`.

### A hidden prompt is a hang

Found by the final review, after all four tasks had passed their own.

`gum spin` hands its child the real terminal on **both** stdin and stdout, and
Homebrew 6 defaults to ask mode (`HOMEBREW_ASK`, escaped only by
`HOMEBREW_NO_ASK`), whose sole guard is `!$stdin.tty? || !$stdout.tty?`. On a
bare Mac every requested formula pulls dependencies — `gnupg` alone has 18 —
so `brew install` asks `[y/n]`, gum buffers the child's output so the question
never reaches the screen, and the run spins forever. `--show-error` does not
help: it flushes on a non-zero exit, and the command never exits. Minutes of
real downloading happen first, so the hang looks like progress.

Verified:

```
gum spin child, as shipped        -> TTY
gum spin child, exec 0</dev/null  -> NOTTY
```

Two changes, because they cover different ground:

- The gum branch of `step` runs `sh -c "exec </dev/null; $cmd"`. Any child
  that tries to prompt from behind a spinner now fails fast instead of
  blocking. That covers the whole class, not just Homebrew — a `sudo -v` that
  failed earlier would otherwise let a cask prompt invisibly too.
- `export HOMEBREW_NO_ASK=1` keeps the *plain* path unattended as well, which
  is what `prime_sudo` promised.

**The plain branch keeps its terminal, deliberately.** When gum is off a
prompt is visible and answerable; suppressing it there would trade a working
question for a silent failure. The asymmetry is the point, and the code says
so at the branch.

### Asking before the payload

Added after the fact. Losing Homebrew's confirmation turned out to be worth
reversing — but it had to move, not come back.

`gum confirm "Install N Homebrew formulae and casks?"` runs immediately
before the bundle step, and only there. N is counted off `BREW_PACKAGES` at
run time rather than written out, so adding a package cannot leave the
question quoting a stale number. It replaces the question
`HOMEBREW_NO_ASK=1` suppresses, asked somewhere it can be seen: before the
spinner starts rather than from behind it. Declining records
`brew packages,skipped` in the summary and lets the rest of the run continue.

#### Two prompt implementations

`confirm` originally proceeded without asking whenever the gum gate was off,
on the reasoning that a gate-off run has nobody to answer. That conflated two
different questions. The gum gate answers *can we draw a TUI* and requires
both `-t 0` and `-t 1`; asking requires only *is anyone there*, which is `-t
0` alone. They come apart in one case, and it is not a hypothetical: `brew
install gum` fails, you are sitting at the terminal, and 26 packages install
without a question.

So there is a second implementation — a plain `read -r -p "$1 [Y/n] "`, gated
on `-t 0`. gum draws the prompt when it can; `read` asks when it cannot but
someone is still there; a run with no terminal on stdin proceeds untouched.
Blocking on a question nobody can see remains the failure mode, not the safe
default.

The asymmetry with `detect_gum` is deliberate. Under `./setup.sh | tee
setup.log` the gum gate is off (`-t 1` fails) but there is still a person on
stdin, and `read`'s prompt goes to stderr — so the question reaches them and
stays out of the log.

Two self-test cases hold the line, and the second is the subtle one: piped
stdin must not be read as an answer. `printf 'n\n' | confirm …` proceeds,
because a pipe is not a person — treating it as one would both misread the
input and eat a line the script needed. `-t 0`, not "stdin has bytes", is the
test.

The placement is still a compromise worth naming: gum does not exist until
the script installs it, so the earliest a *styled* prompt can appear is after
the Homebrew bootstrap and the sudo prompt. You are asked about the
26-package payload, not about the whole run. Asking at line 1 is now
mechanically possible — the `read` path would serve it — but it would put the
question before the script knows whether it can even reach Homebrew.

### Not writing shell hooks for tools that failed to install

`append_once` for `mise activate` and `zoxide init` is guarded on
`command -v`. Without the guard, a failed `brew install` still seeded
`.zshrc`, and every new terminal then printed `command not found` — the one
path that left a fresh machine worse than untouched.

`step "mise runtimes"` stays unguarded: it reports its own failure in the
summary table, so it has none of the silence that made the `.zshrc` writes
worth guarding.

### Header comment

The usage comment at the top of `setup.sh` becomes:

```
#   bash <(curl -fsSL https://raw.githubusercontent.com/Thejus-Paul/dev-setup/main/setup.sh)
#
# Or from a clone: git clone <this repo> && cd dev-setup && ./setup.sh
```

Process substitution, not `curl … | bash`. With the pipe form bash reads the
script from stdin, so a child command such as `brew install` can consume
un-executed script bytes, and `gum spin` gets a pipe where it needs a
terminal. `bash <(…)` leaves stdin on the terminal.

The curl form also sidesteps a bare-Mac wrinkle: `/usr/bin/curl` is a real
binary, while `/usr/bin/git` is a stub that pops the Xcode Command Line Tools
installer. Homebrew installs those tools itself a minute later.

The one-liner returns 404 until the repo is made public. Until then the clone
form is the working entry point, and both are documented.

## Dropping Rust

On a freshly formatted Mac, `cargo install ripgrep topgrade zoxide
cargo-update` means a cold registry and no cached dependencies: roughly 5–15
minutes of compilation, preceded by a ~300MB rustup toolchain download. All
three tools are bottled in Homebrew — prebuilt, ~10–20 seconds for the set,
and at current versions (ripgrep 15.2.0, zoxide 0.10.0, topgrade 17.9.0).

Nothing else on the new machine needs a Rust toolchain, so it does not get
installed. The day it is needed, `rustup` is one command.

Changes:

- `ripgrep topgrade zoxide` join `BREW_PACKAGES`.
- `CARGO_PACKAGES` is deleted.
- The `rustup` block and the `. "$HOME/.cargo/env"` line are deleted.
- The `cargo install` step is deleted.

`cargo-update` is **deleted, not moved to brew.** Its only job is updating
cargo-installed binaries, and it runs as the `cargo install-update`
subcommand. With no toolchain there is no `cargo` to invoke it and nothing for
it to update, so the brew formula would install an unusable binary.

`append_once 'zoxide init zsh'` **stays.** zoxide is still installed, just by
brew, and still needs its `.zshrc` line. This is the easy thing to delete by
accident while removing the cargo block directly above it.

Effect on the TUI: the summary table drops from five steps to four, and the
second-longest step disappears.

## Testing

`--self-test` gains a case for the plain branch, which is the one most likely
to rot:

- `GUM=0`, run `step` over a command that succeeds and one that fails.
- Assert `RESULTS` holds exactly `ok` for the first and `FAILED` for the
  second.
- Assert `step` does not abort the script on the failing command.

The existing `append_once` idempotency case stays as-is. `--self-test`
installs nothing and never calls `main()`, so it touches neither sudo nor the
gum branch — that is deliberate, it must stay runnable on any machine.

## Size

Roughly 55 lines added and 10 deleted (`run()`, `CARGO_PACKAGES`, the rustup
and cargo blocks). `setup.sh` only.
