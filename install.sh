#!/bin/sh
# Frey installer for Linux and macOS (AD116):
#
#   curl -fsSL https://raw.githubusercontent.com/lannerk/frey-releases/main/install.sh | sh
#
# Reads manifests/frey.json, picks this machine's package, downloads it, checks its SHA-256 (and its
# minisign signature when minisign is installed), puts `frey` in ~/.local/bin and adds that directory to
# your PATH if it is not there yet (one line, marked "# added by frey installer", in your shell's startup
# file). No sudo. Running it again upgrades. Nothing on the machine changes until the download checks out.
#
#   FREY_VERSION=0.9.2      this version instead of the newest
#   FREY_INSTALL_DIR=~/bin  another directory
#   HTTPS_PROXY=...         a proxy (curl and wget read it)
#
# Uninstall: curl -fsSL https://raw.githubusercontent.com/lannerk/frey-releases/main/uninstall.sh | sh
# (or `frey uninstall`). Keys and models are not asked here: the first `frey` opens its setup panel.
set -u

REPO_URL=${FREY_INSTALL_REPO:-https://github.com/lannerk/frey-releases}
MANIFEST_URL="https://raw.githubusercontent.com/lannerk/frey-releases/main/manifests/frey.json"
# keys/frey.pub, second line (the release signing key).
PUBLIC_KEY="RWQ2XW3PfirV24ha44zy9+pE4RgJvsrci2wp7Jy//zSPy6Y35D8WQ3J+"
GLIBC_FLOOR="2.28"
MARK="# added by frey installer"

say() { printf '%s\n' "$*"; }
fail() { printf 'frey install: %s\n' "$*" >&2; exit 1; }

# A file at $1 to $2: https:// with curl or wget; a local path is copied (the release workflow's test).
fetch() {
  case "$1" in
    http://* | https://*)
      if command -v curl > /dev/null 2>&1; then
        code=$(curl -sSL --retry 2 -o "$2" -w '%{http_code}' "$1" 2> "$2.err")
        rc=$?
        if [ $rc -ne 0 ]; then
          fail "no answer from $1 ($(head -n 1 "$2.err")); check the network or HTTPS_PROXY"
        fi
        [ "$code" = 200 ] || fail "$1: HTTP $code"
      elif command -v wget > /dev/null 2>&1; then
        wget -q -O "$2" "$1" || fail "could not download $1 (no answer, or not found); check the network or HTTPS_PROXY"
      else
        fail "neither curl nor wget is installed"
      fi
      ;;
    *)
      [ -f "$1" ] || fail "$1: no such file"
      cp "$1" "$2" || fail "copying $1"
      ;;
  esac
}

sha256_of() {
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  elif command -v shasum > /dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d ' ' -f 1
  elif command -v openssl > /dev/null 2>&1; then
    openssl dgst -sha256 "$1" | sed 's/^.*= *//'
  else
    fail "no SHA-256 tool (sha256sum, shasum or openssl) to check the download with"
  fi
}

# This machine's platform name in the manifest (docs/ops/release.md section 3.3).
platform() {
  os=$(uname -s)
  arch=$(uname -m)
  case "$arch" in
    x86_64 | amd64) arch=x86_64 ;;
    aarch64 | arm64) arch=aarch64 ;;
    *) fail "this machine is $arch; Frey is built for x86_64 and aarch64 (arm64)" ;;
  esac
  case "$os" in
    Linux)
      # glibc 2.28 or newer (AD111): musl (Alpine) and older systems cannot run the package.
      glibc=${FREY_TEST_GLIBC:-}
      if [ -z "$glibc" ]; then
        glibc=$(getconf GNU_LIBC_VERSION 2> /dev/null | sed -n 's/^glibc //p')
      fi
      if [ -z "$glibc" ]; then
        glibc=$(ldd --version 2>&1 | head -n 1 | grep -o '[0-9][0-9]*\.[0-9][0-9]*$')
      fi
      [ -n "$glibc" ] || fail "this Linux has no glibc (musl?); Frey needs glibc $GLIBC_FLOOR or newer"
      lowest=$(printf '%s\n%s\n' "$glibc" "$GLIBC_FLOOR" | sort -t . -k 1,1n -k 2,2n | head -n 1)
      [ "$lowest" = "$GLIBC_FLOOR" ] || fail "this Linux has glibc $glibc; Frey needs $GLIBC_FLOOR or newer (RHEL / Rocky 8, Debian 10, Ubuntu 20.04 and later)"
      echo "linux-$arch"
      ;;
    Darwin)
      # An x86_64 shell under Rosetta on Apple silicon: the native build.
      if [ "$arch" = x86_64 ] && [ "$(sysctl -n sysctl.proc_translated 2> /dev/null)" = 1 ]; then
        arch=aarch64
      fi
      echo "macos-$arch"
      ;;
    *) fail "this is $os; this script is for Linux and macOS (Windows: install.ps1)" ;;
  esac
}

# The manifest's entry for a platform, one field: entry FILE PLATFORM FIELD. The platform objects hold no
# braces, so the object is the text from `"<platform>":` to the next `}`.
entry() {
  tr -d '\n\r' < "$1" | awk -v key="\"$2\"" -v field="\"$3\"" '{
    i = index($0, key ":"); if (i == 0) { i = index($0, key " :") } if (i == 0) exit
    rest = substr($0, i); j = index(rest, "}"); obj = substr(rest, 1, j)
    k = index(obj, field); if (k == 0) exit
    v = substr(obj, k + length(field)); sub(/^[ \t]*:[ \t]*/, "", v)
    if (substr(v, 1, 1) == "\"") { v = substr(v, 2); e = index(v, "\""); while (e > 1 && substr(v, e - 1, 1) == "\\") { e = e + index(substr(v, e + 1), "\"") } v = substr(v, 1, e - 1) }
    else { sub(/[,} \t].*$/, "", v) }
    print v
  }'
}

main() {
  dir=${FREY_INSTALL_DIR:-$HOME/.local/bin}
  case "$dir" in "~"/*) dir="$HOME/${dir#"~/"}" ;; esac
  plat=$(platform) || exit 1
  tmp=$(mktemp -d 2> /dev/null || mktemp -d -t frey) || fail "no temporary directory"
  trap 'rm -rf "$tmp"' EXIT INT TERM

  fetch "${FREY_INSTALL_MANIFEST:-$MANIFEST_URL}" "$tmp/frey.json"
  latest=$(grep -o '"version": *"[^"]*"' "$tmp/frey.json" | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/')
  [ -n "$latest" ] || fail "the manifest has no version (not manifests/frey.json?)"
  want=${FREY_VERSION:-$latest}
  want=${want#v}
  if [ "$want" = "$latest" ]; then
    url=$(entry "$tmp/frey.json" "$plat" url)
    [ -n "$url" ] || fail "frey $latest has no package for $plat"
    sum=$(entry "$tmp/frey.json" "$plat" sha256)
    built=$(entry "$tmp/frey.json" "$plat" version)
    [ -n "$built" ] && say "frey $latest has no $plat package; installing $built, the newest one for $plat"
    minisig=$(entry "$tmp/frey.json" "$plat" minisig)
  else
    # Another release: its package and SHA256SUMS from its Release page.
    name="frey-$want-$plat.tar.gz"
    url="$REPO_URL/releases/download/v$want/$name"
    fetch "$REPO_URL/releases/download/v$want/SHA256SUMS" "$tmp/SHA256SUMS"
    sum=$(grep "  $name\$" "$tmp/SHA256SUMS" | cut -d ' ' -f 1)
    [ -n "$sum" ] || fail "frey $want has no package for $plat"
    minisig=""
  fi
  name=${url##*/}
  say "Downloading $name"
  fetch "$url" "$tmp/$name"
  got=$(sha256_of "$tmp/$name")
  [ "$got" = "$sum" ] || fail "$name does not match its SHA-256 (expected $sum, got $got); nothing was installed"
  if command -v minisign > /dev/null 2>&1; then
    if [ -z "$minisig" ]; then
      case "$url" in
        http://* | https://*) fetch "$url.minisig" "$tmp/$name.minisig" ;;
        *) [ -f "$url.minisig" ] && cp "$url.minisig" "$tmp/$name.minisig" ;;
      esac
    else
      printf '%b\n' "$minisig" > "$tmp/$name.minisig"
    fi
    if [ -f "$tmp/$name.minisig" ]; then
      minisign -Vq -P "$PUBLIC_KEY" -m "$tmp/$name" -x "$tmp/$name.minisig" > /dev/null 2>&1 ||
        fail "$name: the signature does not check against the Frey release key; nothing was installed"
      say "Signature checked (minisign)."
    fi
  fi
  mkdir -p "$tmp/x" && tar -xzf "$tmp/$name" -C "$tmp/x" || fail "could not unpack $name"
  [ -f "$tmp/x/frey" ] || fail "$name holds no frey"

  mkdir -p "$dir" || fail "cannot create $dir"
  # Into place in one rename: a frey running now keeps its old file.
  cp "$tmp/x/frey" "$dir/.frey.new.$$" && chmod 755 "$dir/.frey.new.$$" && mv -f "$dir/.frey.new.$$" "$dir/frey" ||
    { rm -f "$dir/.frey.new.$$"; fail "cannot write $dir/frey"; }
  version=$("$dir/frey" --version 2>&1 | head -n 1)
  case "$version" in
    frey\ *) ;;
    *) fail "$dir/frey does not start: $version" ;;
  esac
  say "Installed $version"
  say "  -> $dir/frey"

  # PATH: nothing to do when the directory is on it already.
  case ":$PATH:" in
    *":$dir:"*) say "$dir is on your PATH."; added="" ;;
    *) added=$(add_to_path "$dir") ;;
  esac
  say ""
  if [ -n "$added" ]; then
    say "Added $dir to your PATH in $added."
    say "Open a new terminal (or run: . $added), then run: frey"
  else
    say "Run: frey"
  fi
  say "The first run asks for a provider and its API key."
}

# One marked line in the startup file of the shell in $SHELL; prints the file.
add_to_path() {
  shown=$1
  case "$1" in "$HOME"/*) shown="\$HOME/${1#"$HOME"/}" ;; esac
  case "${SHELL##*/}" in
    zsh) rc="$HOME/.zshrc"; line="export PATH=\"$shown:\$PATH\" $MARK" ;;
    bash)
      # macOS terminals start login shells: ~/.bash_profile; Linux ones read ~/.bashrc.
      if [ "$(uname -s)" = Darwin ]; then rc="$HOME/.bash_profile"; else rc="$HOME/.bashrc"; fi
      line="export PATH=\"$shown:\$PATH\" $MARK"
      ;;
    fish)
      rc="$HOME/.config/fish/config.fish"
      line="fish_add_path -g \"$shown\" $MARK"
      ;;
    *) rc="$HOME/.profile"; line="export PATH=\"$shown:\$PATH\" $MARK" ;;
  esac
  mkdir -p "$(dirname "$rc")"
  if [ -f "$rc" ] && grep -qF "$line" "$rc"; then
    echo "$rc"
    return
  fi
  { [ -s "$rc" ] && [ -n "$(tail -c 1 "$rc")" ] && echo; echo "$line"; } >> "$rc" || fail "cannot write $rc"
  echo "$rc"
}

main "$@"
