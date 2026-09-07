#!/usr/bin/env bash
# Static checks: bash -n + shellcheck (if available).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCRIPTS=(
  setup.sh
  lib/common.sh
  lib/backup.sh
  lib/sync.sh
  lib/mirrors.sh
  lib/ui.sh
  lib/registry.sh
  modules/brew.sh
  modules/apps.sh
  modules/mise.sh
  modules/fonts.sh
  modules/alacritty.sh
  modules/zsh.sh
  modules/tmux.sh
  modules/neovim.sh
  modules/pip.sh
  modules/git.sh
  scripts/doctor.sh
  scripts/check.sh
  scripts/update-mirrors.sh
)

echo "==> bash -n"
fail=0
for f in "${SCRIPTS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "missing: $f"
    fail=1
    continue
  fi
  if bash -n "$f"; then
    echo "  ok  $f"
  else
    echo "  FAIL $f"
    fail=1
  fi
done

echo ""
if command -v shellcheck >/dev/null 2>&1; then
  echo "==> shellcheck"
  # SC1091: sourced files resolved at runtime; SC2034: registry arrays used by setup
  if shellcheck -x -e SC1091,SC2034 "${SCRIPTS[@]}"; then
    echo "  shellcheck passed"
  else
    fail=1
  fi
else
  echo "==> shellcheck (skipped — not installed)"
fi

echo ""
if [[ $fail -ne 0 ]]; then
  echo "check failed"
  exit 1
fi
echo "all checks passed"
