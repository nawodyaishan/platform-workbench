#!/usr/bin/env bash
# Verified downloads shared by modules (Linux only). Sourced only.
# shellcheck disable=SC2034,SC2015

# sha256_file <path>: print the file's SHA-256.
sha256_file() {
  if have sha256sum; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# go_latest_version: newest stable Go release without the "go" prefix (e.g. 1.27.1).
go_latest_version() {
  curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '[.[] | select(.stable)][0].version' | sed 's/^go//'
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

# apt_repo_keyed <name> <key-url> <fingerprints> <deb-line>: add a vendor apt repository.
# Every primary key in the downloaded keyring must be one of the space-separated pinned
# fingerprints, so an extra key slipped into the file fails closed. No-op when both exist.
apt_repo_keyed() {
  local name=$1 url=$2 allowed=$3 line=$4 key got fpr
  local ring="/usr/share/keyrings/$name.gpg" list="/etc/apt/sources.list.d/$name.list"
  if [ -f "$ring" ] && [ -f "$list" ]; then ok "$name apt repository"; return 0; fi
  if is_dry_run; then dry_note "add fingerprint-checked $name apt repository"; return 0; fi
  key=$(mktemp)
  if ! curl -fsSL "$url" -o "$key"; then rm -f "$key"; bad "could not download the $name apt key"; return 1; fi
  got=$(gpg --show-keys --with-colons "$key" 2>/dev/null | awk -F: '$1=="pub" {p=1; next} $1=="fpr" && p {print $10; p=0}')
  [ -n "$got" ] || { rm -f "$key"; bad "no key found in the $name apt key file"; return 1; }
  for fpr in $got; do
    case " $allowed " in *" $fpr "*) ;; *) rm -f "$key"; bad "unexpected $name apt key fingerprint: $fpr"; return 1 ;; esac
  done
  # Some vendors publish an ASCII-armored key, others a binary keyring.
  if grep -q -- '-----BEGIN PGP' "$key"; then gpg --dearmor < "$key" | $SUDO tee "$ring" >/dev/null
  else $SUDO install -m 0644 "$key" "$ring"; fi
  rm -f "$key"
  printf '%s\n' "$line" | $SUDO tee "$list" >/dev/null
  $SUDO apt-get update -qq >/dev/null 2>&1 || warn "apt-get update failed after adding $name"
  changed "configured $name apt repository"
}
