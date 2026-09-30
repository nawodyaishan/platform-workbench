#!/usr/bin/env bash
# Scan files Git would see (tracked plus untracked-not-ignored) for credentials and private
# infrastructure details. This is a public repository: addresses, tailnet names, and
# personal email addresses are treated as leaks, not just keys and tokens.
#
#   check-secrets.sh            scan the working tree
#   check-secrets.sh --staged   scan only staged files (pre-commit hook)
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

if [ "${1:-}" = --staged ]; then
  list() { git diff --cached --name-only -z --diff-filter=ACMR; }
else
  list() { git ls-files -z --cached --others --exclude-standard; }
fi

# name|extended regex. Documentation ranges (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24)
# and example.com/example.org addresses are deliberately not matched.
patterns=(
  'private key|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
  'AWS access key|AKIA[0-9A-Z]{16}'
  'GitHub token|(gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,})'
  'Tailscale key|tskey-[a-z]+-[A-Za-z0-9]+'
  'Slack token|xox[abprs]-[A-Za-z0-9-]{10,}'
  'credential assignment|(password|passwd|token|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9/+_.-]{8,}'
  'private IPv4|(^|[^0-9.])(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}([^0-9]|$)'
  'Tailscale CGNAT IPv4|(^|[^0-9.])100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}([^0-9]|$)'
  'tailnet name|[A-Za-z0-9-]+\.ts\.net'
  'email address|[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+\.)+[A-Za-z]{2,}'
)
# Email matches that are fine to publish.
allow_email='@(example\.(com|org|net)|users\.noreply\.github\.com|noreply\.anthropic\.com)'

found=0
files=()
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  case "$f" in scripts/check-secrets.sh) continue ;; esac
  files+=("$f")
  case "$f" in
    *.pem|*.key|*.p12|*.tfstate|*.tfstate.*|*.tfvars|.env|.env.*|*/.env|*kubeconfig*|*.local.conf|\
    id_rsa|id_ecdsa|id_ed25519|*/id_rsa|*/id_ecdsa|*/id_ed25519|id_ed25519_*|*/id_ed25519_*)
      case "$f" in *.pub|*.example) ;; *) echo "sensitive file name: $f"; found=1 ;; esac ;;
  esac
done < <(list)

if [ ${#files[@]} -gt 0 ]; then
  for entry in "${patterns[@]}"; do
    name=${entry%%|*}; re=${entry#*|}
    hits=$(grep -nIE -- "$re" "${files[@]}" 2>/dev/null || true)
    [ "$name" != 'email address' ] || hits=$(printf '%s\n' "$hits" | grep -vE "$allow_email" || true)
    if [ -n "$hits" ]; then
      printf '%s:\n%s\n' "$name" "$(printf '%s\n' "$hits" | sed 's/^/  /' | cut -c1-200)"
      found=1
    fi
  done
fi

if [ "$found" -eq 1 ]; then
  echo 'Potential secret or private detail found. Remove it or move it to an untracked local file.' >&2
  exit 1
fi
echo "Secret scan: ok (${#files[@]} files)"
