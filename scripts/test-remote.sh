#!/usr/bin/env bash
# No real SSH connection or host modification. Exercises payload boundaries and task aliases.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
tmp=$(mktemp -d)
local_override="$ROOT/config/ssh/test-$$.local.conf"
private_key="$ROOT/config/ssh/id_ed25519_test_$$"
trap 'rm -f "$local_override" "$private_key"; rm -rf "$tmp"' EXIT
: > "$local_override"
: > "$private_key"
"$ROOT/scripts/remote.sh" payload | tar -tzf - > "$tmp/contents"
if grep -Eq 'test-[0-9]+\.local\.conf|id_ed25519_test_' "$tmp/contents"; then
  echo 'untracked SSH file leaked into payload' >&2; exit 1
fi
# shellcheck source=../bootstrap/lib/hosts.sh
. "$ROOT/bootstrap/lib/hosts.sh"
hosts=$(hosts_list)
[ -n "$hosts" ] || { echo 'host registry is empty' >&2; exit 1; }
for host in $hosts; do
  ssh -G -F "$ROOT/config/ssh/workbench.conf" "$host" 2>/dev/null > "$tmp/$host"
  grep -q '^forwardagent no$' "$tmp/$host"
  grep -q '^serveraliveinterval 30$' "$tmp/$host"
  grep -q '/.ssh/cm/' "$tmp/$host"
done
cat > "$tmp/ssh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$WB_TEST_LOG"
STUB
chmod +x "$tmp/ssh"
export WB_TEST_LOG="$tmp/ssh.log"
for host in $hosts; do
  PATH="$tmp:$PATH" task ssh HOST="$host"
  grep -q "^-t $host .*tmux new-session -A -s main" "$WB_TEST_LOG"
done
for short in rhel:rhel-lab ubuntu:ubuntu-lab proxmox:proxmox; do
  PATH="$tmp:$PATH" task "${short%%:*}"
  grep -q "^-t ${short#*:} .*tmux new-session -A -s main" "$WB_TEST_LOG"
done

# Guard rails: unregistered hosts and remote-controlled flags are refused before any SSH.
: > "$WB_TEST_LOG"
if PATH="$tmp:$PATH" "$ROOT/scripts/remote.sh" bootstrap not-a-host --dry-run 2>/dev/null; then
  echo 'unregistered host accepted' >&2; exit 1
fi
if PATH="$tmp:$PATH" "$ROOT/scripts/remote.sh" bootstrap rhel-lab --profile ubuntu 2>/dev/null; then
  echo '--profile override accepted' >&2; exit 1
fi
plan=$(PATH="$tmp:$PATH" "$ROOT/scripts/remote.sh" bootstrap rhel-lab --dry-run)
grep -q 'modules: base shell git ssh' <<< "$plan"
plan=$(PATH="$tmp:$PATH" "$ROOT/scripts/remote.sh" bootstrap proxmox --dry-run)
grep -q 'modules: base shell ssh tailscale$' <<< "$plan"
[ ! -s "$WB_TEST_LOG" ] || { echo 'dry-run or refused call reached ssh' >&2; exit 1; }
echo 'Remote payload, host registry, SSH defaults and tmux session tasks: ok'
