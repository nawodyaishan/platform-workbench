#!/usr/bin/env bash
# Install a pre-commit hook: secret scan of staged files, then prettier on staged Markdown
# when prettier is available.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hook_path="$(git rev-parse --git-path hooks)/pre-commit"
[ ! -e "$hook_path" ] || cp -p "$hook_path" "$hook_path.bak"

cat >"$hook_path" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
"$root/scripts/check-secrets.sh" --staged

staged_md="$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.md$' || true)"
[ -n "$staged_md" ] || exit 0
if ! command -v prettier >/dev/null 2>&1; then
  echo "prettier not found; skipping Markdown formatting"
  exit 0
fi
printf '%s\n' "$staged_md" | xargs prettier --write
printf '%s\n' "$staged_md" | xargs git add
HOOK

chmod +x "$hook_path"
echo "Installed pre-commit hook in $repo_root: $hook_path"
