#!/usr/bin/env bash
# Verified downloads shared by modules (Linux only). Sourced only.
# shellcheck disable=SC2034,SC2015

# sha256_file <path>: print the file's SHA-256.
sha256_file() {
  if have sha256sum; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# go_install_tarball <version>: replace /usr/local/go with a checksum-verified release.
go_install_tarball() {
  local ver=$1 file url sum want tmp
  file="go$ver.linux-$ARCH.tar.gz"
  url="https://go.dev/dl/$file"
  want=$(curl -fsSL 'https://go.dev/dl/?mode=json&include=all' | jq -r --arg f "$file" '.[].files[] | select(.filename==$f) | .sha256' | head -1)
  [ -n "$want" ] || { bad "could not find a published checksum for go$ver"; return 0; }
  tmp=$(mktemp)
  curl -fsSL "$url" -o "$tmp" || { rm -f "$tmp"; bad "download failed: $url"; return 0; }
  sum=$(sha256_file "$tmp")
  if [ "$sum" != "$want" ]; then rm -f "$tmp"; bad "go checksum mismatch"; return 0; fi
  $SUDO rm -rf /usr/local/go && $SUDO tar -C /usr/local -xzf "$tmp" && changed "installed go$ver to /usr/local/go"
  rm -f "$tmp"
}
