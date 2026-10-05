#!/usr/bin/env bash
# Repository structure, host registry consistency, and relative Markdown links.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
rc=0
for path in bootstrap/workbench.sh bootstrap/hosts.conf config/shell/aliases.sh config/tmux/tmux.conf \
            config/vim/vimrc config/ssh/workbench.conf kodekloud/cka-shell.sh docs/new-machine.md \
            kodekloud/k8s/k8s-shell.sh kodekloud/terraform/terraform-shell.sh kodekloud/aws/aws-shell.sh \
            kodekloud/ansible/ansible-shell.sh kodekloud/linux/linux-shell.sh; do
  [ -f "$path" ] || { echo "missing file: $path" >&2; rc=1; }
done

# Paste-in scripts are pasted alone, so each carries its own copy of the basic linux block.
# Keep the copies byte-identical.
block_sums=$(for f in kodekloud/*/*-shell.sh; do
  sed -n '/^# >>> basic linux >>>$/,/^# <<< basic linux <<<$/p' "$f" | cksum
done | sort -u | wc -l | tr -d ' ')
[ "$block_sums" = 1 ] || { echo "kodekloud/*/*-shell.sh: the basic linux block differs between scripts (or is missing)" >&2; rc=1; }

# One canonical copy of each config: no stray duplicates elsewhere in the tree.
dupes=$(git ls-files --cached --others --exclude-standard | grep -E '(^|/)(\.?tmux\.conf|\.?vimrc|aliases\.sh)$' \
  | grep -vxE 'config/tmux/tmux\.conf|config/vim/vimrc|config/shell/aliases\.sh' || true)
[ -z "$dupes" ] || { printf 'duplicate config outside config/:\n%s\n' "$dupes" >&2; rc=1; }

# Every registered host needs an SSH alias, and every workbench alias needs a profile.
# shellcheck source=../bootstrap/lib/hosts.sh
. bootstrap/lib/hosts.sh
ssh_hosts=$(awk 'tolower($1)=="host" && $2!="*" {for (i=2; i<=NF; i++) print $i}' config/ssh/workbench.conf | sort)
reg_hosts=$(hosts_list | sort)
if [ "$ssh_hosts" != "$reg_hosts" ]; then
  echo "bootstrap/hosts.conf and config/ssh/workbench.conf disagree:" >&2
  diff <(printf '%s\n' "$reg_hosts") <(printf '%s\n' "$ssh_hosts") >&2 || true
  rc=1
fi
for h in $reg_hosts; do
  p=$(host_profile "$h")
  [ -r "bootstrap/profiles/$p.sh" ] || { echo "host $h uses unknown profile $p" >&2; rc=1; }
done

# The command reference (scripts/help.sh) must list exactly the public tasks and make targets.
help_cmds=$(sed -n "/^COMMANDS='$/,/^'$/p" scripts/help.sh | awk -F';' 'NF>1 {print $2}' | sort)
task_cmds=$(awk '/^tasks:/ {t=1; next} t && /^  [a-z][a-z0-9:-]*:$/ {sub(/:$/, ""); sub(/^  /, ""); print}' Taskfile.yml \
  | grep -vxE 'default|help' | sort)
make_cmds=$(awk -F':' '/^[a-z][a-z0-9 -]*:/ {n=split($1, t, " "); for (i=1; i<=n; i++) print t[i]}' Makefile \
  | grep -vxE 'help|preflight' | sort)
if [ "$help_cmds" != "$task_cmds" ]; then
  echo "scripts/help.sh and Taskfile.yml list different commands:" >&2
  diff <(printf '%s\n' "$help_cmds") <(printf '%s\n' "$task_cmds") >&2 || true
  rc=1
fi
if [ "$(printf '%s\n' "$help_cmds" | tr ':' '-' | sort)" != "$make_cmds" ]; then
  echo "scripts/help.sh and the Makefile list different commands:" >&2
  diff <(printf '%s\n' "$help_cmds" | tr ':' '-' | sort) <(printf '%s\n' "$make_cmds") >&2 || true
  rc=1
fi

python3 - "$ROOT" <<'PY' || rc=1
from pathlib import Path
from urllib.parse import unquote
import re, sys

root = Path(sys.argv[1])
failures = []
for doc in root.rglob('*.md'):
    if any(part.startswith('.') for part in doc.relative_to(root).parts):
        continue
    text = re.sub(r'```.*?```', '', doc.read_text(errors='replace'), flags=re.S)
    for target in re.findall(r'(?<!!)\[[^\]]+\]\(([^)]+)\)', text):
        target = target.strip().split(' ', 1)[0].strip('<>')
        if not target or target.startswith(('#', 'https:', 'http:', 'mailto:')):
            continue
        path = unquote(target.split('#', 1)[0])
        if path and not (doc.parent / path).exists():
            failures.append(f'{doc.relative_to(root)} -> {target}')
if failures:
    print('Broken relative Markdown links:\n' + '\n'.join(failures), file=sys.stderr)
    sys.exit(1)
PY
[ "$rc" -eq 0 ] && echo 'Repository structure, host registry, command reference and Markdown links: ok'
exit "$rc"
