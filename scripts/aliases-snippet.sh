#!/usr/bin/env bash
# Print a self-contained paste-in installer for config/shell/aliases.sh and functions.sh.
# Paste the output into any bash or zsh prompt (or pipe it to sh). It writes one marker block
# into ~/.zshrc or ~/.bashrc (~/.bash_profile for bash on macOS), backing the file up first.
# Re-pasting replaces the block in place. PW_RC=<file> overrides the target file.
# The snippet is generated on demand, so the canonical files stay the only copy.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUTER=__PLATFORM_WORKBENCH_ALIASES__
INNER=__PW_BLOCK__
sources="$ROOT/config/shell/aliases.sh $ROOT/config/shell/functions.sh"

for f in $sources; do
  [ -r "$f" ] || { echo "missing $f" >&2; exit 1; }
  if grep -qxE "$OUTER|$INNER|# (>>>|<<<) platform-workbench aliases (>>>|<<<)" "$f"; then
    echo "$f contains a line the snippet reserves" >&2
    exit 1
  fi
done

# The outer quoted heredoc keeps the interactive shell from parsing comments: zsh
# rejects pasted `#` lines unless INTERACTIVE_COMMENTS is set.
cat <<EOF
PW_SHELL="\${ZSH_VERSION:+zsh}\${BASH_VERSION:+bash}" /bin/sh -s <<'$OUTER'
# platform-workbench aliases installer, generated from $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
set -eu
begin='# >>> platform-workbench aliases >>>'
end='# <<< platform-workbench aliases <<<'
shell=\${PW_SHELL:-}
[ -n "\$shell" ] || case \${SHELL:-} in */zsh) shell=zsh ;; *) shell=bash ;; esac
if [ -n "\${PW_RC:-}" ]; then rc=\$PW_RC
elif [ "\$shell" = zsh ]; then rc=\$HOME/.zshrc
elif [ "\$(uname -s)" = Darwin ]; then rc=\$HOME/.bash_profile
else rc=\$HOME/.bashrc
fi
if [ -f "\$rc" ] && grep -qx '# >>> platform-workbench >>>' "\$rc"; then
  echo "\$rc already loads platform-workbench through bootstrap; nothing to do."
  exit 0
fi
tmp=\$(mktemp "\${TMPDIR:-/tmp}/pw-aliases.XXXXXX")
trap 'rm -f "\$tmp" "\$tmp.rc"' EXIT
cat >"\$tmp" <<'$INNER'
# >>> platform-workbench aliases >>>
# Managed by the platform-workbench paste-in installer. Paste it again to update;
# delete this block to remove. Keep your own aliases outside the markers.
EOF

for f in $sources; do
  printf '\n# --- %s ---\n' "${f#"$ROOT"/}"
  grep -v '^# shellcheck ' "$f"
done

cat <<EOF
# <<< platform-workbench aliases <<<
$INNER
if [ -s "\$rc" ]; then
  backup=\$rc.pw-backup.\$(date +%Y%m%d%H%M%S)
  cp -p "\$rc" "\$backup"
  echo "backup: \$backup"
fi
touch "\$rc"
if grep -qx "\$begin" "\$rc"; then
  awk -v b="\$begin" -v e="\$end" -v f="\$tmp" '
    \$0 == b { while ((getline line < f) > 0) print line; skip = 1; next }
    skip && \$0 == e { skip = 0; next }
    !skip' "\$rc" >"\$tmp.rc"
  action=updated
else
  { cat "\$rc"; [ ! -s "\$rc" ] || echo; cat "\$tmp"; } >"\$tmp.rc"
  action=added
fi
cat "\$tmp.rc" >"\$rc"
echo "\$action the platform-workbench aliases block in \$rc"
echo "load it now with:  . \$rc"
$OUTER
EOF
