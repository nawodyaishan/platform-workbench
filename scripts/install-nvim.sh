#!/usr/bin/env bash
# Install Neovim 0.12+, the tree-sitter CLI and this repo's nvim config on a Linux host.
#
#   install-nvim.sh [--dry-run] [--no-lsp]
#
# Everything goes under $HOME with no root: Neovim in ~/.local/opt/nvim, tree-sitter and an
# nvim shim in ~/.local/bin (ahead of /usr/bin on PATH, so a distro nvim 0.11 cannot win),
# and ~/.config/nvim symlinked to config/nvim. Downloads are checked against the sha256
# digest GitHub publishes for each asset. Re-running is safe: current pieces are skipped,
# and an existing ~/.config/nvim that is not this link is moved aside as *.bak.<timestamp>.
set -euo pipefail

NVIM_VERSION=0.12.6
TREE_SITTER_VERSION=0.27.2

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OPT_NVIM="$HOME/.local/opt/nvim"
BIN_DIR="$HOME/.local/bin"
CONFIG_SRC="$ROOT/config/nvim"
CONFIG_DEST="$HOME/.config/nvim"

DRY_RUN=0
WITH_LSP=1
ARCH=""
TS_ARCH=""
TMP=""

# --- Output helpers -----------------------------------------------------------------

usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"; }
die()  { printf 'FAIL %s\n' "$*" >&2; exit 1; }
step() { printf '== %s\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# run <cmd...>: execute, or only describe it under --dry-run.
run() {
  if [ "$DRY_RUN" = 1 ]; then say "would run: $*"; else "$@"; fi
}

# version_line <cmd...>: first line of a version banner, or empty if the command is missing.
version_line() {
  { "$@" 2>/dev/null || true; } | sed -n '1p'
}

# --- Checks and downloads -------------------------------------------------------------

detect_platform() {
  [ "$(uname -s)" = Linux ] || die "Linux only; on macOS the bootstrap nvim module links the config"
  case "$(uname -m)" in
    x86_64)        ARCH=x86_64; TS_ARCH=x64 ;;
    aarch64|arm64) ARCH=arm64;  TS_ARCH=arm64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac
  local tool
  for tool in curl tar gzip sha256sum awk; do
    have "$tool" || die "$tool is required"
  done
}

# release_digest <owner/repo> <tag> <asset>: the sha256 GitHub publishes for one asset.
# The release JSON is captured whole before awk reads it; an early exit from awk would
# close the pipe while curl is still writing and fail the download.
release_digest() {
  local json
  json=$(curl -fsSL "https://api.github.com/repos/$1/releases/tags/$2") || return 1
  printf '%s\n' "$json" | awk -v name="\"name\": \"$3\"" '
    index($0, name) { found = 1; next }
    found && /"digest":/ && !done { sub(/.*"sha256:/, ""); sub(/".*/, ""); print; done = 1 }'
}

# fetch_verified <owner/repo> <tag> <asset> <dest>: download an asset and check its digest.
fetch_verified() {
  local repo=$1 tag=$2 asset=$3 dest=$4 want got
  want=$(release_digest "$repo" "$tag" "$asset") || die "cannot read release metadata for $repo $tag"
  [ -n "$want" ] || die "no sha256 digest published for $asset ($repo $tag)"
  curl -fsSL -o "$dest" "https://github.com/$repo/releases/download/$tag/$asset"
  got=$(sha256sum "$dest" | awk '{print $1}')
  [ "$got" = "$want" ] || die "checksum mismatch for $asset: got $got, want $want"
  say "ok   verified $asset"
}

# link <target> <path>: make <path> a symlink to <target>. A different file or link already
# at <path> is moved aside, never deleted.
link() {
  local target=$1 path=$2
  if [ -L "$path" ] && [ "$(readlink "$path")" = "$target" ]; then
    say "ok   $path -> $target"
    return 0
  fi
  if [ "$DRY_RUN" = 1 ]; then say "would link $path -> $target"; return 0; fi
  mkdir -p "$(dirname "$path")"
  if [ -e "$path" ] || [ -L "$path" ]; then
    mv "$path" "$path.bak.$(date +%Y%m%d%H%M%S)"
    say "moved $path aside"
  fi
  ln -s "$target" "$path"
  say "chg  linked $path -> $target"
}

# --- Steps ----------------------------------------------------------------------------

install_nvim() {
  step "neovim $NVIM_VERSION"
  local want="NVIM v$NVIM_VERSION" cur
  cur=$(version_line "$OPT_NVIM/bin/nvim" --version)
  if [ "$cur" = "$want" ]; then
    say "ok   $cur"
  elif [ "$DRY_RUN" = 1 ]; then
    say "would install neovim $NVIM_VERSION to $OPT_NVIM"
  else
    fetch_verified neovim/neovim "v$NVIM_VERSION" "nvim-linux-$ARCH.tar.gz" "$TMP/nvim.tar.gz"
    rm -rf "$OPT_NVIM"
    mkdir -p "$OPT_NVIM"
    tar -xzf "$TMP/nvim.tar.gz" -C "$OPT_NVIM" --strip-components=1
    say "chg  installed $(version_line "$OPT_NVIM/bin/nvim" --version)"
  fi
  link "$OPT_NVIM/bin/nvim" "$BIN_DIR/nvim"
}

install_tree_sitter() {
  step "tree-sitter CLI $TREE_SITTER_VERSION"
  local want="tree-sitter $TREE_SITTER_VERSION" cur
  cur=$(version_line "$BIN_DIR/tree-sitter" --version)
  if [ "$cur" = "$want" ]; then
    say "ok   $cur"
    return 0
  fi
  if [ "$DRY_RUN" = 1 ]; then say "would install $want to $BIN_DIR"; return 0; fi
  fetch_verified tree-sitter/tree-sitter "v$TREE_SITTER_VERSION" \
    "tree-sitter-linux-$TS_ARCH.gz" "$TMP/tree-sitter.gz"
  gzip -dc "$TMP/tree-sitter.gz" > "$TMP/tree-sitter"
  chmod 755 "$TMP/tree-sitter"
  mkdir -p "$BIN_DIR"
  mv -f "$TMP/tree-sitter" "$BIN_DIR/tree-sitter"
  say "chg  installed $want"
}

link_config() {
  step "config"
  link "$CONFIG_SRC" "$CONFIG_DEST"
}

install_language_servers() {
  step "language servers"
  if [ "$WITH_LSP" = 0 ]; then say "skip --no-lsp"; return 0; fi

  if have go; then
    if have gopls || [ -x "$HOME/go/bin/gopls" ]; then
      say "ok   gopls"
    else
      run go install golang.org/x/tools/gopls@latest || say "WARN gopls install failed"
    fi
  else
    say "n/a  go missing, gopls skipped"
  fi

  if have npm; then
    if have typescript-language-server && have yaml-language-server; then
      say "ok   typescript-language-server, yaml-language-server"
    else
      run npm install -g typescript-language-server typescript yaml-language-server \
        || say "WARN npm install failed (a global npm prefix that needs root is the usual cause)"
    fi
  else
    say "n/a  npm missing, typescript and yaml servers skipped"
  fi
}

verify() {
  step "verify"
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) say "WARN $BIN_DIR is not on PATH; add it so plain nvim finds the 0.12 shim" ;;
  esac
  if [ "$DRY_RUN" = 1 ]; then say "would headless-load $CONFIG_DEST/init.lua"; return 0; fi

  local log="$TMP/load.log"
  if ! "$OPT_NVIM/bin/nvim" --headless -u "$CONFIG_DEST/init.lua" \
      -c 'lua vim.wait(3000)' -c 'messages' -c 'qa' >"$log" 2>&1; then
    cat "$log" >&2
    die "headless load exited non-zero"
  fi
  if grep -Eq '^E[0-9]+:|Error detected|stack traceback' "$log"; then
    cat "$log" >&2
    die "headless load reported errors"
  fi
  say "ok   headless load, $(version_line "$OPT_NVIM/bin/nvim" --version)"
}

# --- Entry point ----------------------------------------------------------------------

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --no-lsp)  WITH_LSP=0 ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  detect_platform
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT

  install_nvim
  install_tree_sitter
  link_config
  install_language_servers
  verify

  printf 'done. Open a new shell, or run: hash -r, so %s is found first.\n' "$BIN_DIR/nvim"
}

main "$@"
