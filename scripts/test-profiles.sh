#!/usr/bin/env bash
# Smoke-test the bootstrap profiles inside throwaway containers.
#
#   scripts/test-profiles.sh [rhel|ubuntu|proxmox|ubuntu-devstack ...]
#                                          (default: rhel ubuntu proxmox)
#
# Each run: dry-run, bootstrap, verify, then a second bootstrap that must change nothing
# (idempotence). Uses whatever container engine `docker` points at (OrbStack here).
# Images: rhel=rockylinux:9, ubuntu=ubuntu:24.04, proxmox=debian:bookworm-slim
# (proxmox runs with --force-profile and a fake pveversion; systemd is not available, so
# service checks that need it are expected to warn or n/a rather than pass).
# ubuntu-devstack is opt-in and heavy (Go, Node, Rust, Temurin, Homebrew...): the ubuntu
# profile with --extras devstack, limited to the modules `task devstack` runs.
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
    ubuntu|ubuntu-devstack) echo ubuntu:24.04 ;;
    proxmox) echo debian:bookworm-slim ;;
  esac
}

# Runs inside the container as root; drops to an unprivileged user for non-proxmox profiles.
# shellcheck disable=SC2016  # expanded inside the container, not here
INNER='
set -euo pipefail
profile=$1 extra=""
if [ "$profile" = ubuntu-devstack ]; then
  profile=ubuntu; extra="--extras devstack --only base,shell,containers,k8s,devstack"
fi
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
  run() { su tester -c "/repo/bootstrap/workbench.sh $* --profile $profile --force-profile --yes $extra"; }
  # Legacy marker fixture: blocks from the previous toolkit name (including its main block)
  # must be migrated into the single new block.
  printf "# >>> ops-workbench >>>\nexport OPS_WORKBENCH_HOME=/old\n# <<< ops-workbench <<<\n# >>> ops-workbench dotfiles >>>\nalias old=1\n# <<< ops-workbench dotfiles <<<\n# >>> ops-workbench nvm >>>\nx=1\n# <<< ops-workbench nvm <<<\n" > /home/tester/.bashrc
  chown tester /home/tester/.bashrc
  if [ -n "$extra" ]; then
    # Standalone pnpm fixture (what get.pnpm.io leaves): its rc block must go and its binary
    # must lose to the corepack pnpm.
    printf "\n# pnpm\nexport PNPM_HOME=/home/tester/.local/share/pnpm\ncase \":\$PATH:\" in\n  *\":\$PNPM_HOME/bin:\"*) ;;\n  *) export PATH=\"\$PNPM_HOME/bin:\$PATH\" ;;\nesac\n# pnpm end\n" >> /home/tester/.bashrc
    install -d -o tester /home/tester/.local /home/tester/.local/share /home/tester/.local/share/pnpm /home/tester/.local/share/pnpm/bin
    printf "#!/bin/sh\necho standalone\n" > /home/tester/.local/share/pnpm/bin/pnpm; chmod +x /home/tester/.local/share/pnpm/bin/pnpm
  fi
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
if [ -n "$extra" ]; then
  # A new login shell must find every tool through the canonical bashrc alone.
  su - tester -c "bash -ic \"for c in node npm yarn pnpm go rustc cargo java mvn terraform aws gh kind brew docker kubectl helm agentic-sdd; do command -v \\\$c >/dev/null || { echo MISSING: \\\$c; exit 1; }; done\"" 2>/dev/null \
    && echo "DEVSTACK-ON-PATH" || { echo "DEVSTACK-NOT-ON-PATH"; exit 1; }
  for d in .claude/skills .codex/skills .agents/skills .gemini/antigravity-cli/skills; do
    [ -f "/home/tester/$d/agentic-sdd-router/SKILL.md" ] || { echo "SKILLS-MISSING: $d"; exit 1; }
  done
  echo "AGENTIC-SDD-SKILLS-OK"
  if grep -qx "# pnpm" /home/tester/.bashrc; then echo "PNPM-BLOCK-NOT-REMOVED"; exit 1; fi
  su - tester -c "bash -ic \"case \\\$(command -v pnpm) in */.nvm/*) pnpm bin -g ;; *) exit 1 ;; esac\"" 2>/dev/null | grep -qx /home/tester/.local/share/pnpm/bin \
    && echo "PNPM-FROM-DEVSTACK" || { echo "PNPM-NOT-FROM-DEVSTACK"; exit 1; }
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
  seconds=900; [ "$p" = ubuntu-devstack ] && seconds=2700
  if limited "$seconds" docker run --rm --name "$active_container" -v "$ROOT:/repo:ro" "$img" bash -c "$INNER" _ "$p"; then
    echo "PASS $p"
  else
    echo "FAIL $p"; rc=1
  fi
  cleanup
  active_container=""
done
exit $rc
