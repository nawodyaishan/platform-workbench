#!/usr/bin/env bash
# Command reference behind `task`, `task help` and `make help`.
#
#   scripts/help.sh [--make] [COMMAND]
#
# One table drives both front-ends so they cannot drift; scripts/check-repo.sh checks it
# against Taskfile.yml and the Makefile. --make prints make target names and ARGS= syntax.
# Needs only Bash and awk, so `make help` works before Task is installed.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mode=task
[ "${1:-}" != --make ] || { mode="make"; shift; }
topic=${1:-}

# group;command;arguments (task form);description[;arguments (make form, when it differs)]
# Keep `;` out of the fields. In make form, a trailing `[-- X]` becomes `[ARGS="X"]`.
COMMANDS='
Lifecycle;bootstrap;[HOST=alias | PROFILE=name] [-- FLAGS];Install and wire a profile, locally or on HOST
Lifecycle;update;[HOST=alias | PROFILE=name] [-- FLAGS];Upgrade profile-managed packages and refresh config
Lifecycle;verify;[HOST=alias | PROFILE=name] [-- FLAGS];Read-only health check, exits 1 on failure
Lifecycle;verify:all;;Verify the Mac and every registered host
Dev toolchain;devstack;[-- --dry-run];Install the full-stack toolchain on this Ubuntu host
Dev toolchain;devstack:update;[-- --dry-run];Upgrade Node LTS, Go, Rust, AWS CLI, kind and apt tools
Dev toolchain;devstack:verify;;Read-only check of the dev toolchain
Sessions;main;;Attach to or create the local tmux session "main"
Sessions;ssh;HOST=alias;SSH to HOST and attach its tmux session "main"
Sessions;rhel;;Open a session on rhel-rhcsa01
Sessions;ubuntu;;Open a session on dev-01
Sessions;proxmox;;Open a session on proxmox
Host access;hosts;;List registered hosts, SSH targets and reachability
Host access;ssh:copy-id;HOST=alias [KEY=path.pub];Install a public key on HOST for first contact
Host access;gh-key;HOST=alias;Create a distinct GitHub key on HOST
Install;install:task;[-- --distro NAME --method repo|binary --dry-run];Install Task on this Linux host;[DISTRO=name] [METHOD=repo|binary]
Install;install:ubuntu;[-- --dry-run];Install Task and the ubuntu profile on this host
Install;install:rhel;[-- --dry-run];Install Task and the rhel profile on this host
Install;install:proxmox;[-- --dry-run];Install Task and the minimal proxmox profile, as root
Shell;aliases;;Copy the paste-in aliases installer to the clipboard
Shell;install:aliases;;Install only the aliases and functions on this machine
Labs;kk;[TOPIC=cka|k8s|terraform|aws|ansible|linux];Copy a KodeKloud shell snippet to the clipboard
Quality;check;;Run lint, secrets and repo checks
Quality;lint;;Syntax-check scripts and validate every config
Quality;secrets;;Scan for credentials and private infrastructure details
Quality;repo;;Check structure, host registry and Markdown links
Quality;test:remote;;Offline tests for the remote flow and session tasks
Quality;test:profiles;[-- rhel ubuntu proxmox ubuntu-devstack];Container smoke tests for the Linux profiles
Quality;hooks;;Install the pre-commit hook
'

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
  B=$(printf '\033[1m'); D=$(printf '\033[2m'); R=$(printf '\033[0m')
else
  B=""; D=""; R=""
fi

name_of() { # <mode> <command>
  if [ "$1" = make ]; then printf '%s' "$2" | tr ':' '-'; else printf '%s' "$2"; fi
}
args_of() { # <mode> <task-form args> <make-form args>
  if [ "$1" = task ]; then printf '%s' "$2"
  elif [ -n "$3" ]; then printf '%s' "$3"
  else printf '%s' "$2" | sed 's/\[-- \(.*\)\]$/[ARGS="\1"]/'; fi
}
line_of() { # <mode> <command> <task-form args> <make-form args>
  printf '%s %s %s' "$1" "$(name_of "$1" "$2")" "$(args_of "$1" "$3" "$4")" | sed 's/ *$//'
}
rows() { printf '%s\n' "$COMMANDS" | awk 'NF'; }

run=$mode
if [ "$mode" = make ]; then
  usage="make <target> [VAR=value ...] [ARGS=\"FLAGS\"]"
  more="make help CMD=<target>"; flagnote='pass with ARGS="..."'
else
  usage="task <command> [VAR=value ...] [-- FLAGS]"
  more="task help -- <command>"; flagnote='pass after --'
fi

# --- One command -------------------------------------------------------------------
if [ -n "$topic" ]; then
  want=$(printf '%s' "$topic" | tr '-' ':')
  # Hyphenated task names (gh-key) must still match after the make-to-task mapping.
  row=$(rows | awk -F';' -v a="$topic" -v b="$want" '$2==a || $2==b {print; exit}')
  if [ -z "$row" ]; then
    echo "unknown command: $topic" >&2
    echo "run '$run help' for the list of commands" >&2
    exit 2
  fi
  IFS=';' read -r group cmd targs desc margs <<<"$row"
  margs=${margs:-}
  other="task"; [ "$mode" = task ] && other="make"
  printf '%s\n\n' "$desc"
  printf '%sUSAGE%s\n  %s\n  %s\n\n' "$B" "$R" "$(line_of "$mode" "$cmd" "$targs" "$margs")" \
    "$(line_of "$other" "$cmd" "$targs" "$margs")"
  printf '%sGROUP%s\n  %s\n\n' "$B" "$R" "$group"
  printf '%sDETAILS%s\n  task --summary %s\n' "$B" "$R" "$cmd"
  exit 0
fi

# --- Full reference ----------------------------------------------------------------
printf '%splatform-workbench%s  bootstrap, update and verify a macOS workstation and its lab hosts\n\n' "$B" "$R"
printf '%sUSAGE%s\n  %s\n' "$B" "$R" "$usage"

last=""
while IFS=';' read -r group cmd _ desc _; do
  if [ "$group" != "$last" ]; then
    printf '\n%s%s%s\n' "$B" "$(printf '%s' "$group" | tr '[:lower:]' '[:upper:]')" "$R"
    last=$group
  fi
  printf '  %-18s %s\n' "$(name_of "$mode" "$cmd")" "$desc"
done <<<"$(rows)"

cat <<EOF

${B}FLAGS${R} ${D}(bootstrap, update, verify; $flagnote)${R}
  --dry-run          Print every planned change and make none
  --yes              Skip y/N confirmations (never a typed one)
  --extras LIST      Opt-in modules: go,node,cka,devstack
  --only LIST        Run only these profile modules, in profile order

${B}VARIABLES${R}
  HOST=alias         Act on a registered host over SSH, from the Mac
  PROFILE=name       macos, rhel, ubuntu or proxmox (default on the Mac: macos)
  KEY=path.pub       Public key for $(name_of "$mode" ssh:copy-id) (default ~/.ssh/id_ed25519.pub)
  TOPIC=name         Snippet for kk (default cka)
EOF

printf '\n%sEXAMPLES%s\n' "$B" "$R"
while IFS=';' read -r ex note; do
  printf '  %-44s %s%s%s\n' "$ex" "$D" "$note" "$R"
done <<EOF
$(if [ "$mode" = make ]; then cat <<'MK'
make bootstrap ARGS=--dry-run;Preview the Mac's changes
make verify HOST=dev-01;Health-check a lab host from the Mac
make devstack ARGS=--dry-run;Preview the Ubuntu dev toolchain
make install-task;Fresh Linux host: Task only, no sudo as root
make install-proxmox ARGS=--dry-run;Fresh Proxmox host: Task + profile preview
MK
else cat <<'TK'
task bootstrap -- --dry-run;Preview the Mac's changes
task verify HOST=dev-01;Health-check a lab host from the Mac
task devstack -- --dry-run;Preview the Ubuntu dev toolchain
task bootstrap HOST=dev-01 -- --only shell;Rewire one module on a host
task install:ubuntu -- --dry-run;Fresh Ubuntu host: Task + profile preview
TK
fi)
EOF

# shellcheck source=../bootstrap/lib/hosts.sh
. "$ROOT/bootstrap/lib/hosts.sh"
list=""
for h in $(hosts_list); do list="$list  $h ($(host_profile "$h"))"; done
printf '\n%sREGISTERED HOSTS%s %s(bootstrap/hosts.conf)%s\n%s\n' "$B" "$R" "$D" "$R" "$list"
printf '\nRun %s%s%s for one command. Docs: README.md, docs/.\n' "$B" "$more" "$R"
