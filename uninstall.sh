#!/bin/sh
# Frey uninstaller for Linux and macOS (AD116):
#
#   curl -fsSL https://raw.githubusercontent.com/lannerk/frey-releases/main/uninstall.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/lannerk/frey-releases/main/uninstall.sh | sh -s -- --purge
#
# Removes `frey`, the PATH line the installer added (only lines marked "# added by frey installer") and
# ~/.frey/updates/ (the old versions `frey update` kept). ~/.frey itself - API keys, sessions,
# configuration - stays unless you say so: it asks once (from the terminal; with no terminal the answer is
# no), and --purge deletes it without asking. `frey uninstall` does the same without the network.
#
#   FREY_INSTALL_DIR=~/bin  where frey was installed, when not ~/.local/bin and not on PATH
set -u

MARK="# added by frey installer"

say() { printf '%s\n' "$*"; }
fail() { printf 'frey uninstall: %s\n' "$*" >&2; exit 1; }

main() {
  purge=""
  for arg in "$@"; do
    case "$arg" in
      --purge) purge=1 ;;
      *) fail "unknown argument $arg (only --purge)" ;;
    esac
  done
  [ "${FREY_PURGE:-}" = 1 ] && purge=1

  if [ -n "${FREY_INSTALL_DIR:-}" ]; then
    dir=$FREY_INSTALL_DIR
    case "$dir" in "~"/*) dir="$HOME/${dir#"~/"}" ;; esac
  elif [ -f "$HOME/.local/bin/frey" ]; then
    dir="$HOME/.local/bin"
  elif found=$(command -v frey 2> /dev/null) && [ -f "$found" ]; then
    dir=$(dirname "$found")
  else
    dir="$HOME/.local/bin"
  fi

  if [ -f "$dir/frey" ]; then
    rm -f "$dir/frey" || fail "cannot remove $dir/frey"
    say "Removed $dir/frey"
  else
    say "No frey in $dir (if it is elsewhere, set FREY_INSTALL_DIR)"
  fi
  rm -f "$dir"/.frey.new.* 2> /dev/null

  for rc in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.config/fish/config.fish"; do
    [ -f "$rc" ] && grep -qF "$MARK" "$rc" || continue
    # Rewritten in place (cat >), so the file keeps its owner, mode and links.
    grep -vF "$MARK" "$rc" > "$rc.frey-uninstall" || true
    cat "$rc.frey-uninstall" > "$rc" && rm -f "$rc.frey-uninstall" || fail "cannot rewrite $rc"
    say "Removed the PATH line from $rc"
    # A file the installer created for that one line goes too (nothing else was in it).
    [ -s "$rc" ] || { rm -f "$rc" && say "Removed $rc (it held only that line)"; }
  done

  data="$HOME/.frey"
  if [ -d "$data/updates" ]; then
    rm -rf "$data/updates" && say "Removed $data/updates"
  fi
  if [ -d "$data" ]; then
    if [ -z "$purge" ] && (: < /dev/tty) 2> /dev/null; then
      printf 'Also delete %s (API keys, sessions, configuration)? [y/N] ' "$data" > /dev/tty
      read -r answer < /dev/tty || answer=""
      case "$answer" in y | Y | yes | YES | Yes) purge=1 ;; esac
    fi
    if [ -n "$purge" ]; then
      rm -rf "$data" && say "Removed $data"
    else
      say "Kept $data (API keys, sessions, configuration); --purge deletes it too"
    fi
  fi
  say "frey is uninstalled."
}

main "$@"
