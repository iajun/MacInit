#!/usr/bin/env bash
# Document / refresh Homebrew mirror URL sources.
# Does NOT scrape mirrors automatically — prints authoritative docs + currently
# embedded URLs from lib/mirrors.sh so you can diff after upstream changes.
#
# Authoritative pages:
#   tuna:     https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/
#   ustc:     https://mirrors.ustc.edu.cn/help/brew.git.html
#   bfsu:     https://mirrors.bfsu.edu.cn/help/homebrew/
#   alibaba:  https://developer.aliyun.com/mirror/homebrew
#   brew docs:https://docs.brew.sh/Installation
#
# When a university mirror updates env var names or paths, edit lib/mirrors.sh
# (apply_mirror_env + persist_mirror_choice) and re-run this script to verify.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIRRORS_LIB="$ROOT/lib/mirrors.sh"

echo "==> Authoritative Homebrew mirror docs"
echo "  tuna:  https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/"
echo "  ustc:  https://mirrors.ustc.edu.cn/help/brew.git.html"
echo "  bfsu:  https://mirrors.bfsu.edu.cn/help/homebrew/"
echo "  ali:   https://developer.aliyun.com/mirror/homebrew"
echo ""

echo "==> Embedded URLs in lib/mirrors.sh"
if [[ -f "$MIRRORS_LIB" ]]; then
  grep -E 'https://mirrors\.(tuna|ustc|aliyun|bfsu)|homebrew' "$MIRRORS_LIB" \
    | grep -E 'export HOMEBREW_|https://' \
    | sed 's/^/  /' || true
else
  echo "  missing: $MIRRORS_LIB"
  exit 1
fi

echo ""
echo "Compare the embedded URLs with the help pages above; update lib/mirrors.sh if they drift."
echo "After editing, re-run: ./setup.sh --mirror=<id> --steps=brew --dry-run"
