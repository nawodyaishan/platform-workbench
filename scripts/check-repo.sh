#!/usr/bin/env bash
# Repository structure, host registry consistency, and relative Markdown links.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
rc=0
for path in bootstrap/workbench.sh bootstrap/hosts.conf config/shell/aliases.sh config/tmux/tmux.conf \
            config/vim/vimrc config/ssh/workbench.conf kodekloud/cka-shell.sh docs/new-machine.md; do
  [ -f "$path" ] || { echo "missing file: $path" >&2; rc=1; }
done

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
[ "$rc" -eq 0 ] && echo 'Repository structure, host registry and Markdown links: ok'
exit "$rc"
