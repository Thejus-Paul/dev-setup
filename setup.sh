#!/usr/bin/env bash
#
# Provisions a fresh macOS machine. Run it on a box with nothing installed:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/Thejus-Paul/dev-setup/main/setup.sh)
#
# Or from a clone:
#
#   git clone https://github.com/Thejus-Paul/dev-setup.git && cd dev-setup && ./setup.sh
#
# Process substitution, not `curl … | bash`. The pipe form puts the script on
# stdin, where `brew install` can swallow un-executed script bytes and gum
# finds no terminal to draw on.
#
# Every step is idempotent, so rerunning it is how you top an existing machine
# up. Steps keep going after a failure; the summary table at the end is what to
# read. Pipe the run (`./setup.sh | tee setup.log`) to turn gum off and get the
# full unfiltered output back.

set -uo pipefail

# Homebrew installs the Xcode Command Line Tools as part of its own bootstrap,
# so there is no separate xcode-select step.
BREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
BREW_SHELLENV='eval "$(/opt/homebrew/bin/brew shellenv)"'

# Where install_config reads tracked config files from. SCRIPT_DIR is the checkout when the
# run has one; under the documented `bash <(curl …)` form $0 is a file descriptor, so it
# resolves to /dev/fd, no file is found there, and the fetch falls through to RAW_URL. That
# is the right answer in both cases, so neither needs detecting.
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
RAW_URL="https://raw.githubusercontent.com/Thejus-Paul/dev-setup/main"

# Zoom installation requires a password.
# libyaml, readline and zlib are ruby-build dependencies; shared-mime-info is a mimemagic one.
# `postgresql` is an alias for the latest major, currently postgresql@18.
#
# fd, ripgrep and fff-mcp are one search set, not three overlapping tools: fd matches file
# names, ripgrep searches contents and returns every match, fff-mcp ranks either by frecency
# and truncates, which is what an agent on a token budget wants and what a refactor must not
# trust. fzf is the interactive front end the first two feed.
#
# fff-mcp lives in a tap. Spelled fully-qualified so `brew install` taps on demand, rather
# than spending a step and a summary row on a `brew tap` that only ever serves this one line.
#
# amethyst and loop are both window managers and both stay: loop resizes the one window you
# are dragging, amethyst retiles every window on the space by itself. Neither does the
# other's job, so neither replaces it.
#
# knockknock, oversight and taskexplorer are Objective-See's. They report what a machine
# persists, records and runs rather than blocking any of it, so they cost nothing until asked.
BREW_PACKAGES="amethyst dmtrkovalenko/fff/fff-mcp fd font-fira-code-nerd-font fzf gh gnupg \
helium-browser iina keepassxc knockknock lazygit libyaml loop meetingbar mise mole \
monitorcontrol mos nvim obsidian oversight postgresql raycast readline redis ripgrep rtk \
shared-mime-info slack taskexplorer topgrade warp zlib zoom zoxide"

# Homebrew 6 asks for confirmation before installing dependencies. The gum
# branch of `step` cannot display that prompt, and the plain branch should
# not need it — prime_sudo already promised an unattended run.
export HOMEBREW_NO_ASK=1

# Language runtimes are managed by mise, not rbenv/nvm.
RUNTIMES="ruby@latest node@latest"

# System Settings, read off a machine already tuned by hand so a fresh box
# comes up the same way. One string rather than one call per setting: `step`
# runs its argument through `sh -c`, where a shell function defined here would
# not exist, and twelve spinners for twelve instant writes is noise, not
# progress.
#
# Tap-to-click needs all three writes. The two driver domains are the built-in
# and the Bluetooth trackpad; the -currentHost one is what the Accessibility
# and login-window paths read, and without it the setting looks applied in
# System Settings but does not survive a reboot.
#
# The sudo lines rely on prime_sudo's warm timestamp. Under `gum spin` stdin is
# /dev/null, so a lapsed one fails the step rather than hanging on a password
# prompt nobody can see.
MACOS_SETTINGS='
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock orientation left
defaults write com.apple.dock tilesize -int 52

defaults write com.apple.finder FXPreferredViewStyle Nlsv
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false

defaults write -g AppleInterfaceStyle Dark
defaults write -g com.apple.swipescrolldirection -bool false

defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

defaults write com.apple.WindowManager HideDesktop -bool true
defaults write com.apple.WindowManager StandardHideWidgets -bool true
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
sudo pmset -b displaysleep 2

# Reads the new values into the running processes. Ignored on failure: a
# missing Dock or Finder is not a reason to fail the step, and the settings
# are on disk either way.
killall Dock Finder SystemUIServer 2>/dev/null || true
'

# Per-app preferences, read off the same hand-tuned machine as MACOS_SETTINGS, and filtered
# the same way: only keys that are a deliberate choice and that still mean something on a
# different box. That filter is why three of the new apps write nothing. MonitorControl
# stores brightness per monitor serial, TaskExplorer keeps a first-run flag and an AppKit
# debug toggle, and Amethyst's file here is a leftover from an install that is gone — its
# values are the ones Amethyst ships with, not ones anybody chose.
#
# `defaults write` against a running app is not just ignored, it is reverted: the app holds
# its preferences in memory and writes them back over yours when it quits. Nothing has
# launched yet on the fresh box this script is for. On a rerun, quit the app first.
APP_SETTINGS='
defaults write com.objective-see.oversight startAtLogin -bool true
defaults write com.objective-see.oversight noIconMode -bool true

defaults write com.objective-see.KnockKnock startAtLogin -bool true
defaults write com.objective-see.KnockKnock disableVTQueries -bool true
defaults write com.objective-see.KnockKnock showTrustedItems -bool false

# The trigger is three macOS virtual keycodes: 56 shift, 55 command, 59 control.
defaults write com.MrKai77.Loop trigger -array -int 56 -int 55 -int 59
defaults write com.MrKai77.Loop sideDependentTriggerKey -bool true
defaults write com.MrKai77.Loop useScreenWithCursor -bool true
defaults write com.MrKai77.Loop windowSnapping -bool false
defaults write com.MrKai77.Loop animateWindowResizes -bool false
defaults write com.MrKai77.Loop currentIcon -string "AppIcon-Rose Pine"

defaults write com.raycast.macos raycastPreferredWindowMode -string compact
defaults write com.raycast.macos raycastShouldFollowSystemAppearance -bool true
defaults write com.raycast.macos useHyperKeyIcon -bool false
'

# Accessibility, Screen Recording and Full Disk Access live in the TCC database, which SIP
# protects and the only tool that writes it is Apple-internal. So this is not a step that
# was skipped for brevity — it is one no script can perform. Every app below is inert until
# its box is ticked, which makes naming them the honest end to the run.
TCC_APPS="Accessibility for Amethyst, Loop, MonitorControl and Raycast; Screen Recording, \
microphone and camera for OverSight; Full Disk Access for KnockKnock and TaskExplorer."
ACCESSIBILITY_PANE="x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"

ZSHRC="$HOME/.zshrc"

# 0 until gum is installed and the output is a real terminal. See detect_gum.
GUM=0

# One "<label>,ok" or "<label>,FAILED" entry per step, rendered by summary.
RESULTS=()

# Both -t checks matter. `gum spin` runs a Bubble Tea program: it draws on
# stdout and reads from stdin — terminal capability replies, and ^C. A
# non-terminal on either side breaks it.
#
# stdin is the easy one to miss. `curl … | bash` leaves stdout a terminal
# while bash reads the script itself from stdin, so a stdout-only check
# would switch gum on with no terminal to read from. That is exactly why
# the header documents `bash <(curl …)`, which passes the script as a file
# argument and leaves stdin alone.
#
# No NO_COLOR check here: gum reads NO_COLOR itself, and duplicating it would
# give one variable two meanings. To force plain output, redirect or pipe the
# run — that fails the -t 1 check.
detect_gum() {
  if command -v gum >/dev/null && [ -t 0 ] && [ -t 1 ]; then
    GUM=1
  else
    GUM=0
  fi
}

banner() {
  if [ "$GUM" = 1 ]; then
    gum style --border rounded --padding "1 2" --align center --foreground 212 "$1"
  else
    echo "== $1 =="
  fi
}

note() { # message [level]
  local level="${2:-info}"
  if [ "$GUM" = 1 ]; then
    gum log -l "$level" "$1"
  else
    echo "$level: $1"
  fi
}

# Homebrew's own ask-mode stays disabled (HOMEBREW_NO_ASK above). This is the
# same question asked somewhere it can actually be seen: before the spinner
# starts, rather than from behind it.
#
# Two implementations, because the gum gate answers "can we draw a TUI?" and
# this question needs "is anyone there to answer?" — which is only `-t 0`.
# They come apart in the case that matters: gum failed to install, but you are
# sitting at the terminal. That used to install 26 packages without asking.
#
# `-t 0` alone decides whether to ask. A run that is piped or in CI has nobody
# at the keyboard, so it proceeds; hanging on a question nobody can see is the
# failure mode, not the safe default. Note the deliberate asymmetry with
# detect_gum, which also requires `-t 1`: with stdout piped (`./setup.sh | tee
# setup.log`) there is still a person on stdin, and read's prompt goes to
# stderr, so the question reaches them and stays out of the log.
confirm() { # question
  local reply
  if [ "$GUM" = 1 ]; then
    gum confirm "$1"
    return
  fi

  [ -t 0 ] || return 0
  # Defaults to yes on a bare Enter, matching gum confirm's default button.
  # A read that fails (EOF mid-run) leaves $reply empty and so also proceeds.
  read -r -p "$1 [Y/n] " reply
  case "$reply" in
    [nN]*) return 1 ;;
    *) return 0 ;;
  esac
}

# Always returns 0. A failing step is recorded, not fatal — the summary is the report.
step() { # label command
  local label="$1" cmd="$2" ok
  if [ "$GUM" = 1 ]; then
    # `exec </dev/null;` prefix (not `</dev/null` on $cmd) so it covers the
    # whole sh -c string. gum spin hands its child the real TTY on both
    # stdin and stdout; without this, a child that prompts (e.g. brew's
    # ask-mode) blocks on a prompt nobody can see. The plain branch below
    # is left with its inherited terminal on purpose: there, a prompt is
    # visible and answerable, so it must not be redirected the same way.
    gum spin --title "$label" --show-error -- sh -c "exec </dev/null; $cmd"
  else
    echo "==> $label"
    sh -c "$cmd"
  fi
  ok=$?

  if [ "$ok" = 0 ]; then
    RESULTS+=("$label,ok")
    # "$label ok", not "$label": the plain branch already printed "==> $label"
    # before running, so a bare label here reads as the same line twice.
    note "$label ok"
  else
    RESULTS+=("$label,FAILED")
    note "$label failed (exit $ok)" error
  fi
  return 0
}

summary() {
  local row
  # bash 3.2 aborts on "${RESULTS[@]}" when the array is empty and `set -u` is on.
  [ "${#RESULTS[@]}" -eq 0 ] && return 0

  if [ "$GUM" = 1 ]; then
    printf '%s\n' "STEP,RESULT" "${RESULTS[@]}" | gum table --print
    return 0
  fi

  printf '\n%-16s %s\n' "STEP" "RESULT"
  for row in "${RESULTS[@]}"; do
    printf '%-16s %s\n' "${row%%,*}" "${row##*,}"
  done
}

# gum spin hides its command's output, including sudo's password prompt. Ask
# once here, where the prompt is visible, then keep the timestamp warm: macOS
# expires it after five minutes and the brew run is far longer than that.
prime_sudo() {
  note "Asking for your password once, so the rest of the run is unattended."
  if sudo -v; then
    # `sudo -n` never prompts, so a lapsed timestamp fails quietly instead of hanging.
    while true; do sudo -n true; sleep 60; done 2>/dev/null &
    # Killed by PID, not by the %1 job spec: job control is off in non-interactive shells.
    SUDO_KEEPALIVE_PID=$!
    trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
  else
    note "sudo unavailable; Homebrew and the casks will fail" error
  fi
}

# `needle` is matched loosely so hand-edited variants of `line` (indented, or spelled
# with an absolute path) are left alone rather than duplicated.
append_once() { # needle line file
  grep -qF -- "$1" "$3" 2>/dev/null && return 0
  printf '%s\n' "$2" >>"$3"
  note "appended to $3: $2"
}

# Puts a tracked config file where the app that reads it will look. Same rule as
# append_once: an existing file is left alone, because a config you have edited since
# outranks the snapshot recorded here.
#
# Not routed through `step`, for the same reason append_once is not: `step` runs its
# argument under `sh -c`, where a function defined in this file does not exist.
install_config() { # relative_path destination
  [ -e "$2" ] && return 0
  mkdir -p "$(dirname "$2")" || return 1

  if [ -f "$SCRIPT_DIR/$1" ]; then
    cp "$SCRIPT_DIR/$1" "$2" || { note "could not copy $1" error; return 1; }
  elif ! curl -fsSL "$RAW_URL/$1" -o "$2"; then
    # curl -o creates the file before it knows the request failed, so a 404 would otherwise
    # leave an empty settings file behind — which the app reads as "configured, with nothing".
    rm -f "$2"
    note "could not fetch $1" error
    return 1
  fi

  note "installed $2"
}

main() {
  detect_gum
  banner "dev-setup · macOS bootstrap"
  prime_sudo

  command -v brew >/dev/null ||
    step "homebrew" "NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL $BREW_INSTALL_URL)\""

  # Homebrew's installer prints PATH advice but never applies it.
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    append_once 'brew shellenv' "$BREW_SHELLENV" "$ZSHRC"
  fi

  # gum installs on its own line, before the bundle, so the longest step
  # is the first one that gets a spinner.
  step "gum" "brew install gum"
  detect_gum

  if confirm "Install $(set -- $BREW_PACKAGES; echo $#) Homebrew formulae and casks?"; then
    step "brew packages" "brew install $BREW_PACKAGES"
  else
    RESULTS+=("brew packages,skipped")
    # warn, not error: you answered the question. Red is for things that broke.
    note "brew packages skipped" warn
  fi

  # Guarded on the tool existing: if "brew packages" failed, appending an
  # activation line for a tool that isn't there just leaves every new
  # terminal printing "command not found".
  command -v mise >/dev/null && append_once 'mise activate zsh' 'eval "$(mise activate zsh)"' "$ZSHRC"
  step "mise runtimes" "mise use --global $RUNTIMES"

  command -v zoxide >/dev/null && append_once 'zoxide init zsh' 'eval "$(zoxide init zsh)"' "$ZSHRC"

  # `fzf --zsh` emits the keybindings (^R, ^T, M-c) and completions in one blob; the older
  # two-line key-bindings.zsh/completion.zsh pair is what it replaced. Sourced rather than
  # eval'd because that is the form fzf documents, and the needle matches either spelling.
  command -v fzf >/dev/null && append_once 'fzf --zsh' 'source <(fzf --zsh)' "$ZSHRC"

  # A brew install leaves fff-mcp inert: it is a server Claude Code has to be told about.
  # Claude Code is not installed here, hence the first guard. The `mcp get` probe is the
  # idempotency guard — `mcp add` fails on a name that already exists, which would turn
  # every rerun into a FAILED row. User scope, so it resolves outside this one directory.
  if command -v fff-mcp >/dev/null && command -v claude >/dev/null &&
    ! claude mcp get fff >/dev/null 2>&1; then
    step "fff mcp" "claude mcp add --scope user fff $(command -v fff-mcp)"
  fi

  # rtk is equally inert on its own: the hook that rewrites commands reads its instructions
  # out of ~/.claude, and a brew install puts nothing there. No probe guard here, unlike
  # `mcp add` above — `init` appends one @RTK.md line to CLAUDE.md, leaves the rest of that
  # file alone and no-ops on a rerun. It does not create ~/.claude though, so the guard is on
  # the directory rather than on `claude` being on PATH.
  if command -v rtk >/dev/null && [ -d "$HOME/.claude" ]; then
    step "rtk init" "rtk init --global"
  fi

  # Asked, like the package bundle, because this is the other step that changes
  # a machine you may already be happy with: it moves the Dock, turns the
  # firewall on and restarts Finder. On a fresh box the answer is yes; on a
  # rerun it is the one step you might want to skip.
  if confirm "Apply macOS System Settings (Dock, Finder, trackpad, firewall)?"; then
    step "macos settings" "$MACOS_SETTINGS"
  else
    RESULTS+=("macos settings,skipped")
    note "macos settings skipped" warn
  fi

  # Its own question rather than a rider on the one above, because it is a different
  # promise: that one rearranges the desktop, this one only touches preference files for
  # apps the bundle just installed. Answering no to one is not answering no to the other.
  if confirm "Apply app preferences (Loop, Raycast, OverSight, KnockKnock)?"; then
    step "app settings" "$APP_SETTINGS"
  else
    RESULTS+=("app settings,skipped")
    note "app settings skipped" warn
  fi

  # Warp is the one app here that does not keep its settings in defaults. It migrated to
  # ~/.warp/settings.toml, and its own documentation treats the dev.warp.Warp-Stable plist
  # as leftover state to delete on uninstall rather than as configuration. The plist is
  # still written, which is what makes it a trap: on this machine it had already drifted
  # from the real settings on five of six keys, theme and vertical tabs included.
  #
  # Unguarded, unlike the append_once calls above. A .zshrc line for a missing tool breaks
  # every new terminal; a settings file for a missing Warp is just a file, and it is already
  # correct whenever Warp does arrive.
  install_config config/warp/settings.toml "$HOME/.warp/settings.toml"
  install_config config/warp/keybindings.yaml "$HOME/.warp/keybindings.yaml"

  summary
  echo
  note "Grant these by hand, once: $TCC_APPS" warn
  # Opened only with a terminal on stdout, on the same reasoning as detect_gum: a piped or
  # CI run has nobody to tick the boxes, and System Settings taking focus from a background
  # run is a bug. `|| true` so a failed open does not become main's exit status.
  [ -t 1 ] && { open "$ACCESSIBILITY_PANE" || true; }

  echo
  echo "Done. Open a new terminal, or: source $ZSHRC"
  # Only true when the spinner actually ran. A piped run already printed every
  # caveat in full, so pointing at `brew info` there is advice for a run that
  # did not happen.
  #
  # An `&&` one-liner here would make main's exit status 1 on a plain run,
  # because this is the last statement.
  if [ "$GUM" = 1 ]; then
    echo "The spinner hid install caveats (e.g. how to start services): brew info postgresql redis"
  fi
}

self_test() {
  local file mise zoxide
  RESULTS=()
  file="$(mktemp -t dev-setup)"

  # A hand-edited variant of a line we would otherwise write.
  printf '  eval "$(/opt/homebrew/opt/mise/bin/mise activate zsh)"\n' >"$file"

  append_once 'mise activate zsh' 'eval "$(mise activate zsh)"' "$file"
  append_once 'zoxide init zsh' 'eval "$(zoxide init zsh)"' "$file"
  append_once 'zoxide init zsh' 'eval "$(zoxide init zsh)"' "$file"

  mise=$(grep -cF 'mise activate zsh' "$file")
  zoxide=$(grep -cF 'zoxide init zsh' "$file")
  rm -f "$file"

  if [ "$mise" != 1 ] || [ "$zoxide" != 1 ]; then
    echo "FAIL: mise=$mise zoxide=$zoxide (both should be 1)"
    exit 1
  fi
  echo "ok: append_once is idempotent"

  # install_config must never clobber. Seeding a fresh box is the whole point; overwriting
  # the settings.toml you have been editing since would be the opposite of it.
  local cfgdir dest
  cfgdir="$(mktemp -d -t dev-setup-config)"
  dest="$cfgdir/settings.toml"
  printf 'mine\n' >"$dest"
  install_config config/warp/settings.toml "$dest" >/dev/null
  if [ "$(cat "$dest")" != "mine" ]; then
    echo "FAIL: install_config overwrote an existing file"
    rm -rf "$cfgdir"
    exit 1
  fi
  echo "ok: install_config leaves an existing file alone"

  # And it must copy when there is nothing there yet. Guarded on the checkout existing, so
  # that running --self-test through `bash <(curl …)` skips this rather than reaching for
  # the network in the middle of a test.
  if [ -f "$SCRIPT_DIR/config/warp/settings.toml" ]; then
    rm -f "$dest"
    install_config config/warp/settings.toml "$dest" >/dev/null
    if ! grep -q '^font_name' "$dest" 2>/dev/null; then
      echo "FAIL: install_config did not copy the tracked settings.toml"
      rm -rf "$cfgdir"
      exit 1
    fi
    echo "ok: install_config copies the tracked config into place"
  fi
  rm -rf "$cfgdir"

  # step records each outcome and never aborts the run
  GUM=0
  RESULTS=()
  step "passing" "true" >/dev/null
  step "failing" "false" >/dev/null
  if [ "${RESULTS[0]}" != "passing,ok" ] || [ "${RESULTS[1]}" != "failing,FAILED" ]; then
    echo "FAIL: step recorded ${RESULTS[*]-}"
    exit 1
  fi
  echo "ok: step records ok and FAILED, and continues past a failure"

  # summary must not abort on an empty array: bash 3.2 treats "${RESULTS[@]}"
  # as an unbound variable under `set -u` when the array has no elements.
  RESULTS=()
  if ! summary >/dev/null; then
    echo "FAIL: summary aborted on empty RESULTS"
    exit 1
  fi
  echo "ok: summary survives an empty RESULTS array"

  # confirm must never block when nobody is there to answer. This is the CI
  # case: no gum to draw the question, no terminal on stdin.
  GUM=0
  if ! confirm "this must not prompt" </dev/null; then
    echo "FAIL: confirm did not auto-proceed with no terminal on stdin"
    exit 1
  fi
  echo "ok: confirm auto-proceeds with no terminal on stdin"

  # The `read` fallback must gate on `-t 0`, not on stdin merely having bytes.
  # A pipe is not a person: piped input is data for the script, and reading an
  # answer out of it would both misread it and eat a line the script needed.
  GUM=0
  if ! printf 'n\n' | confirm "this must not consume piped input"; then
    echo "FAIL: confirm read an answer out of a pipe"
    exit 1
  fi
  echo "ok: confirm does not treat piped input as an answer"

  # The gate stays off when gum is not on PATH. Run in a subshell so the
  # PATH override does not leak; `command -v` and `[` are builtins, so an
  # empty PATH does not break the check itself.
  GUM=1
  if ! ( PATH=/nonexistent; detect_gum; [ "$GUM" = 0 ] ); then
    echo "FAIL: gate stayed on with gum missing from PATH"
    exit 1
  fi
  echo "ok: gum gate stays off when gum is not installed"

  # The gate stays off without a terminal on stdin, which is the CI case and
  # the `curl | bash` case. Meaningful when self-test is run interactively;
  # trivially true when it is not.
  GUM=1
  if ! ( detect_gum </dev/null; [ "$GUM" = 0 ] ); then
    echo "FAIL: gate stayed on with stdin not a tty"
    exit 1
  fi
  echo "ok: gum gate stays off without a terminal"
  GUM=0

  # MACOS_SETTINGS is a block of shell text that nothing parses until the run
  # reaches it, by which point a typo has cost you the whole step. `sh -n`
  # parses without executing, so this catches the typo here and touches no
  # settings on the machine running the test.
  if ! sh -n -c "$MACOS_SETTINGS"; then
    echo "FAIL: MACOS_SETTINGS is not valid shell"
    exit 1
  fi
  echo "ok: MACOS_SETTINGS parses"

  # Same reasoning for APP_SETTINGS, with one addition: it embeds a double-quoted string
  # inside a single-quoted block, which is exactly the kind of quoting that parses wrong
  # long after you stopped looking at it.
  if ! sh -n -c "$APP_SETTINGS"; then
    echo "FAIL: APP_SETTINGS is not valid shell"
    exit 1
  fi
  echo "ok: APP_SETTINGS parses"

  # Every domain APP_SETTINGS writes should belong to an app the bundle installs. A rename
  # upstream, or a package dropped from the list, otherwise leaves a `defaults write` that
  # succeeds against nothing at all — defaults creates the domain either way.
  local domain app
  for domain in $(printf '%s\n' "$APP_SETTINGS" | awk '$1 == "defaults" { print $3 }' | sort -u); do
    case "$domain" in
      com.objective-see.oversight) app=oversight ;;
      com.objective-see.KnockKnock) app=knockknock ;;
      com.MrKai77.Loop) app=loop ;;
      com.raycast.macos) app=raycast ;;
      *) echo "FAIL: APP_SETTINGS writes unmapped domain $domain"; exit 1 ;;
    esac
    case " $BREW_PACKAGES " in
      *" $app "*) ;;
      *) echo "FAIL: APP_SETTINGS writes $domain but BREW_PACKAGES has no $app"; exit 1 ;;
    esac
  done
  echo "ok: every APP_SETTINGS domain maps to an installed package"
}

case "${1-}" in
  --self-test) self_test ;;
  *) main ;;
esac
