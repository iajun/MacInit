#!/usr/bin/env bash
# Preflight doctor — readable report of shell-init dependencies & state.
# Can be sourced (doctor_main) or executed.

[[ -n "${_SHELL_INIT_DOCTOR_LOADED:-}" ]] && return 0 2>/dev/null || true
_SHELL_INIT_DOCTOR_LOADED=1

_doctor_setup_dir() {
  if [[ -n "${SETUP_DIR:-}" ]]; then
    echo "$SETUP_DIR"
    return
  fi
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "$(cd "$here/.." && pwd)"
}

doctor_main() {
  local root
  root="$(_doctor_setup_dir)"
  # Ensure libs/modules if not already loaded via setup.sh
  if ! declare -F step_brew_check >/dev/null 2>&1; then
    export SETUP_DIR="$root"
    export PACKAGES_DIR="$root/packages"
    # shellcheck source=../lib/common.sh
    source "$root/lib/common.sh"
    # shellcheck source=../lib/backup.sh
    source "$root/lib/backup.sh"
    # shellcheck source=../lib/sync.sh
    source "$root/lib/sync.sh"
    # shellcheck source=../lib/mirrors.sh
    source "$root/lib/mirrors.sh"
    # shellcheck source=../lib/registry.sh
    source "$root/lib/registry.sh"
    load_modules
  fi

  printf '%s==========================================%s\n' "${C_BOLD:-}" "${C_RESET:-}"
  echo "shell-init doctor"
  printf '%s==========================================%s\n' "${C_BOLD:-}" "${C_RESET:-}"
  echo ""
  echo "系统:"
  echo "  OS:      $(uname -s) $(uname -m)"
  echo "  macOS:   $(sw_vers -productVersion 2>/dev/null || echo n/a)"
  echo "  HOME:    $HOME"
  echo "  SETUP:   $root"
  echo ""

  echo "工具链:"
  local cmd
  for cmd in brew git curl zsh tmux nvim mise; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '  ✓ %-8s %s\n' "$cmd" "$(command -v "$cmd")"
    else
      printf '  ✗ %-8s (未找到)\n' "$cmd"
    fi
  done
  echo ""

  if declare -F clt_installed >/dev/null 2>&1 && clt_installed; then
    echo "  ✓ Xcode CLI: $(clt_path)"
  elif xcode-select -p >/dev/null 2>&1; then
    echo "  ~ Xcode CLI path set: $(xcode-select -p)（编译器可能不完整）"
  else
    echo "  ✗ Xcode CLI: 未安装"
  fi

  local mirror_file="${SHELL_INIT_MIRROR_FILE:-$HOME/.config/shell-init/mirror}"
  if [[ -f "$mirror_file" ]]; then
    echo "  ✓ brew mirror: $(tr -d '[:space:]' <"$mirror_file") ($mirror_file)"
  else
    echo "  · brew mirror: 未持久化（当前 BREW_MIRROR=${BREW_MIRROR:-tuna}）"
  fi
  echo ""

  echo "Git 身份:"
  if command -v git >/dev/null 2>&1; then
    local gn ge
    gn="$(git config --global --get user.name 2>/dev/null || true)"
    ge="$(git config --global --get user.email 2>/dev/null || true)"
    if [[ -n "$gn" && -n "$ge" ]]; then
      echo "  ✓ $gn <$ge>"
    else
      echo "  ✗ user.name / user.email 未完整设置"
    fi
  else
    echo "  ✗ git 不可用"
  fi
  echo ""

  echo "模块状态:"
  local id
  for id in brew apps mise alacritty zsh pip tmux neovim fonts git; do
    echo "── $id ──"
    set +e
    step_check "$id" | sed 's/^/  /'
    set -e
  done

  echo ""
  echo "建议:"
  if ! command -v brew >/dev/null 2>&1 && ! [[ -x /opt/homebrew/bin/brew || -x /usr/local/bin/brew ]]; then
    echo "  → 新机请运行: ./setup.sh --preset=bootstrap -y"
  else
    echo "  → 同步配置: ./setup.sh --preset=config"
    echo "  → 仅 GUI 应用: ./setup.sh --preset=apps-only"
  fi
  echo "  → 预览动作: ./setup.sh --dry-run --preset=bootstrap"
  echo "  → 镜像刷新说明: ./scripts/update-mirrors.sh"
  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  doctor_main "$@"
fi
