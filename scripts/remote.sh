#!/usr/bin/env bash
# Mac-driven lifecycle for the hosts in bootstrap/hosts.conf. The remote host never needs a
# clone of this repository or any Git credential: tracked files are streamed over SSH.
#
#   remote.sh <bootstrap|update|verify> <host> [--dry-run] [--yes] [--extras LIST] [--only MODS]
#   remote.sh gh-key <host>      distinct GitHub key on the host; asks before publishing
#   remote.sh copy-id <host> [public-key-file]   first contact: install a public key only
#   remote.sh hosts              registry, resolved SSH target and read-only reachability
#   remote.sh payload            write the tracked payload tarball to stdout
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
# shellcheck source=../bootstrap/lib/hosts.sh
. "$ROOT/bootstrap/lib/hosts.sh"

# shellcheck disable=SC2088
REMOTE_DIR='~/.local/share/platform-workbench'  # expanded by the remote shell
usage() { sed -n '5,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}/usage: /' >&2; exit 2; }
die() { echo "$*" >&2; exit 2; }
verb=${1:-}; [ $# -gt 0 ] && shift
case "$verb" in bootstrap|update|verify|payload|gh-key|copy-id|hosts) ;; *) usage ;; esac

# Archive only paths known to Git. The filenames are NUL-delimited so spaces are safe.
payload() { git ls-files -z -- bootstrap config kodekloud | tar --null -T - -czf -; }
source_stamp() { printf '%s %s\n' "$(git rev-parse HEAD)" "$(payload | shasum -a 256 | cut -d' ' -f1)"; }

if [ "$verb" = payload ]; then [ $# -eq 0 ] || usage; payload; exit 0; fi

if [ "$verb" = hosts ]; then
  [ $# -eq 0 ] || usage
  printf '%-12s %-8s %-36s %s\n' ALIAS PROFILE TARGET SSH
  for h in $(hosts_list); do
    target=$(ssh -G "$h" 2>/dev/null | awk '$1=="user"{u=$2} $1=="hostname"{n=$2} END{print u "@" n}')
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" true >/dev/null 2>&1; then state=ok; else state=unreachable; fi
    printf '%-12s %-8s %-36s %s\n' "$h" "$(host_profile "$h")" "$target" "$state"
  done
  exit 0
fi

host=${1:-}; [ -n "$host" ] || usage; shift
case "$host" in *[!A-Za-z0-9._-]*) die "invalid host alias: $host" ;; esac
profile=$(host_profile "$host") || die "HOST must be listed in bootstrap/hosts.conf (have: $(hosts_list | tr '\n' ' '))"

if [ "$verb" = copy-id ]; then
  [ $# -le 1 ] || usage
  command -v ssh-copy-id >/dev/null || die 'ssh-copy-id is required on the Mac'
  if [ $# -eq 1 ]; then
    case "$1" in *.pub) ;; *) die 'pass the PUBLIC key file (*.pub); private keys never leave the Mac' ;; esac
    exec ssh-copy-id -i "$1" "$host"
  fi
  exec ssh-copy-id "$host"
fi

if [ "$verb" = gh-key ]; then
  [ $# -eq 0 ] || usage
  command -v gh >/dev/null || die 'gh is required on the Mac'
  read -r -p "Create a separate GitHub key on $host? [y/N] " answer
  case "$answer" in y|Y|yes) ;; *) exit 1 ;; esac
  # Every variable part of these commands is a registered alias validated above.
  ssh -t "$host" "umask 077; mkdir -p ~/.ssh; test ! -e ~/.ssh/id_ed25519_github_${host} || { echo 'key already exists'; exit 1; }; ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github_${host} -C '${host} platform-workbench'"
  ssh "$host" "bash -s -- $host" <<'REMOTE'
set -eu
umask 077
config=$HOME/.ssh/config
if [ -f "$config" ]; then cp -p "$config" "$config.platform-workbench.bak"; fi
if ! grep -Fq '# >>> platform-workbench github >>>' "$config" 2>/dev/null; then
  tmp=$(mktemp "$HOME/.ssh/config.XXXXXX")
  cat > "$tmp" <<'BLOCK'
# >>> platform-workbench github >>>
Host github.com
    IdentityFile ~/.ssh/id_ed25519_github_HOST
    IdentitiesOnly yes
    ForwardAgent no
# <<< platform-workbench github <<<
BLOCK
  sed -i.bak "s/id_ed25519_github_HOST/id_ed25519_github_$1/" "$tmp"
  rm -f "$tmp.bak"
  if [ -f "$config" ]; then cat "$config" >> "$tmp"; fi
  mv "$tmp" "$config"
fi
chmod 600 "$config"
REMOTE
  key=$(ssh "$host" "cat ~/.ssh/id_ed25519_github_${host}.pub")
  printf 'Public key from %s:\n%s\n' "$host" "$key"
  read -r -p "Publish this public key to GitHub? [y/N] " answer
  case "$answer" in y|Y|yes) ;; *) echo 'Key remains on the host; publish later if needed.'; exit 0 ;; esac
  printf '%s\n' "$key" | gh ssh-key add - --title "$host ($(date +%Y-%m-%d))"
  echo "GitHub key published. Revoke with: gh ssh-key list; gh ssh-key delete <id>"
  exit 0
fi

dry=0
for arg in "$@"; do [ "$arg" = --dry-run ] && dry=1; done
if [ "$verb" = verify ]; then
  [ $# -eq 0 ] || die 'remote verify accepts no extra flags'
  local_stamp=$(source_stamp)
  remote_stamp=$(ssh "$host" "cat $REMOTE_DIR/.source-commit 2>/dev/null || true")
  if [ "$remote_stamp" != "$local_stamp" ]; then echo "WARN: $host payload differs from the local tracked content (run: task update HOST=$host)" >&2; fi
  exec ssh -t "$host" "bash $REMOTE_DIR/bootstrap/workbench.sh verify --profile $profile --expect-host $host"
fi

for arg in "$@"; do
  case "$arg" in
    --dry-run|--yes) ;;
    --profile|--force-profile|--expect-host) die "remote controls $arg" ;;
    --extras=*|--only=*) die "use ${arg%%=*} LIST, not ${arg%%=*}=LIST" ;;
    *) case "$arg" in *[!a-zA-Z0-9_,.-]*|'') die "unsafe workbench argument: $arg" ;; esac ;;
  esac
done

if [ "$dry" -eq 1 ]; then
  echo "DRY: would scan for secrets, send $(git ls-files -- bootstrap config kodekloud | wc -l | tr -d ' ') tracked files to $host:$REMOTE_DIR, keep the prior payload as .prev, then run $verb --profile $profile"
  (
    MODULES=(); PKGS_BASE=(); PKGS_NET=(); PKGS_ADMIN=()
    # shellcheck source=/dev/null
    . "$ROOT/bootstrap/profiles/$profile.sh"
    printf '  args: %s\n' "$*"
    printf '  modules: %s\n' "${MODULES[*]-}"
    printf '  base packages: %s\n' "${PKGS_BASE[*]-}"
    printf '  network packages: %s\n' "${PKGS_NET[*]-}"
    printf '  admin packages: %s\n' "${PKGS_ADMIN[*]-}"
  )
  exit 0
fi

"$ROOT/scripts/check-secrets.sh"
if [ "$profile" = proxmox ]; then
  read -r -p 'Type proxmox to confirm remote payload transfer: ' answer
  [ "$answer" = proxmox ] || { echo 'not confirmed' >&2; exit 1; }
fi

# Stage in a private directory; publish only after extraction succeeds. Keep the
# previous payload for a manual rollback. No private key or Git credential is sent.
ssh "$host" "set -eu; umask 077; mkdir -p ~/.local/share; rm -rf $REMOTE_DIR.new; mkdir $REMOTE_DIR.new"
payload | ssh "$host" "tar -xzf - -C $REMOTE_DIR.new"
source_stamp | ssh "$host" "cat > $REMOTE_DIR.new/.source-commit"
ssh "$host" "set -eu; rm -rf $REMOTE_DIR.prev; if [ -d $REMOTE_DIR ]; then mv $REMOTE_DIR $REMOTE_DIR.prev; fi; mv $REMOTE_DIR.new $REMOTE_DIR"
exec ssh -t "$host" "bash $REMOTE_DIR/bootstrap/workbench.sh $verb --profile $profile --expect-host $host $*"
