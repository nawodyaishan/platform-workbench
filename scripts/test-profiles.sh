#!/usr/bin/env bash
# Smoke-test the bootstrap profiles inside throwaway containers.
#
#   scripts/test-profiles.sh [rhel|ubuntu|proxmox ...]     (default: all three)
#
# Each run: dry-run, bootstrap, verify, then a second bootstrap that must change nothing
# (idempotence). Uses whatever container engine `docker` points at (OrbStack here).
# Images: rhel=rockylinux:9, ubuntu=ubuntu:24.04, proxmox=debian:bookworm-slim
# (proxmox runs with --force-profile and a fake pveversion; systemd is not available, so
# service checks that need it are expected to warn or n/a rather than pass).
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
command -v docker >/dev/null 2>&1 || { echo "docker not found" >&2; exit 2; }

limited() { # <seconds> <command>...
  local seconds=$1; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$seconds" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout "$seconds" "$@"
  else "$@"; fi
}
active_container=""
cleanup() { [ -z "$active_container" ] || docker rm -f "$active_container" >/dev/null 2>&1 || true; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

image_for() {
  case "$1" in
    rhel) echo rockylinux:9 ;;
    ubuntu) echo ubuntu:24.04 ;;
    proxmox) echo debian:bookworm-slim ;;
  esac
}

# Runs inside the container as root; drops to an unprivileged user for non-proxmox profiles.
# shellcheck disable=SC2016  # expanded inside the container, not here
INNER='
set -euo pipefail
profile=$1
if [ "$profile" = proxmox ]; then
  apt-get update -qq >/dev/null && apt-get install -y -qq ca-certificates curl gnupg >/dev/null
  printf "#!/bin/sh\necho pve-manager/8.2.0\n" > /usr/local/bin/pveversion; chmod +x /usr/local/bin/pveversion
  # --yes must not bypass the typed confirmation, so type it.
  run() { if [ "$1" = verify ] || [ "${2:-}" = --dry-run ]; then /repo/bootstrap/workbench.sh "$@" --profile proxmox --force-profile; else echo proxmox | /repo/bootstrap/workbench.sh "$@" --profile proxmox --force-profile --yes; fi; }
else
  if command -v dnf >/dev/null; then dnf install -y -q sudo shadow-utils >/dev/null
  else apt-get update -qq >/dev/null && apt-get install -y -qq sudo ca-certificates curl gnupg >/dev/null; fi
  useradd -m tester
  echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester
  run() { su tester -c "/repo/bootstrap/workbench.sh $* --profile $profile --force-profile --yes"; }
  # Legacy marker fixture: blocks from the previous toolkit name (including its main block)
  # must be migrated into the single new block.
  printf "# >>> ops-workbench >>>\nexport OPS_WORKBENCH_HOME=/old\n# <<< ops-workbench <<<\n# >>> ops-workbench dotfiles >>>\nalias old=1\n# <<< ops-workbench dotfiles <<<\n# >>> ops-workbench nvm >>>\nx=1\n# <<< ops-workbench nvm <<<\n" > /home/tester/.bashrc
  chown tester /home/tester/.bashrc
fi
echo "### dry-run";   run bootstrap --dry-run
echo "### bootstrap"; run bootstrap
echo "### verify";    run verify
echo "### rerun";     run bootstrap | tee /tmp/rerun.log
grep -q "changed=0" /tmp/rerun.log && echo "IDEMPOTENT" || { echo "NOT-IDEMPOTENT"; exit 1; }
if [ "$profile" = proxmox ]; then
  for c in docker podman kubectl go node; do
    if command -v "$c" >/dev/null; then echo "EXCLUSION-VIOLATED: $c"; exit 1; fi
  done
  echo "PROXMOX-EXCLUSIONS-OK"
else
  if grep -q "ops-workbench" /home/tester/.bashrc; then echo "LEGACY-NOT-MIGRATED"; exit 1; fi
  grep -qF "# >>> platform-workbench >>>" /home/tester/.bashrc && echo "LEGACY-MIGRATED" || { echo "BLOCK-MISSING"; exit 1; }
fi
'

rc=0
profiles=("$@"); [ ${#profiles[@]} -gt 0 ] || profiles=(rhel ubuntu proxmox)
for p in "${profiles[@]}"; do
  img=$(image_for "$p")
  [ -n "$img" ] || { echo "unknown profile: $p" >&2; exit 2; }
  echo; echo "=== $p ($img) ==="
  if ! docker image inspect "$img" >/dev/null 2>&1 && ! limited 180 docker pull -q "$img" >/dev/null 2>&1; then
    echo "FAIL $p: cannot pull $img (docker credential prompt or no network?)"
    rc=1
    continue
  fi
  active_container="platform-workbench-test-$p-$$"
  if limited 900 docker run --rm --name "$active_container" -v "$ROOT:/repo:ro" "$img" bash -c "$INNER" _ "$p"; then
    echo "PASS $p"
  else
    echo "FAIL $p"; rc=1
  fi
  cleanup
  active_container=""
done
exit $rc
