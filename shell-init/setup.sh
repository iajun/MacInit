#!/usr/bin/env bash
# shell-init entrypoint — wizard (no args) or CLI (with args).
#
#   ./setup.sh                         # 交互向导
#   ./setup.sh --preset=bootstrap -y   # 新机全自动
#   ./setup.sh --preset=config         # 仅配置
#   ./setup.sh --preset=apps-only      # 仅 GUI 应用
#   ./setup.sh --dry-run --preset=bootstrap
#   ./setup.sh --mirror=ustc
#   ./setup.sh doctor
#   ./setup.sh --help

set -euo pipefail

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SETUP_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
cd "$SETUP_DIR" || exit 1
export SETUP_DIR
export PACKAGES_DIR="$SETUP_DIR/packages"

# shellcheck source=lib/common.sh
source "$SETUP_DIR/lib/common.sh"
# shellcheck source=lib/backup.sh
source "$SETUP_DIR/lib/backup.sh"
# shellcheck source=lib/sync.sh
source "$SETUP_DIR/lib/sync.sh"
# shellcheck source=lib/mirrors.sh
source "$SETUP_DIR/lib/mirrors.sh"
# shellcheck source=lib/ui.sh
source "$SETUP_DIR/lib/ui.sh"
# shellcheck source=lib/registry.sh
source "$SETUP_DIR/lib/registry.sh"

load_modules
registry_init_selection
require_macos || exit 1

# Prefer persisted mirror when caller did not pass --mirror=
if [[ -z "${BREW_MIRROR_SET:-}" ]]; then
  load_persisted_mirror
fi

declare -a FAILED_STEPS=()
declare -a OK_STEPS=()

run_one_step() {
  local idx="$1"
  local id="${STEP_IDS[idx]}"
  local name="${STEP_NAMES[idx]}"

  log_step "$name"
  set +e
  step_run "$id"
  local code=$?
  set -e

  if [[ $code -eq 0 ]]; then
    log_ok "$name 完成"
    OK_STEPS+=("$name")
    return 0
  fi
  log_err "$name 失败 (exit $code)"
  FAILED_STEPS+=("$name")
  if [[ "$CONTINUE_ON_ERROR" == "1" ]]; then
    return 0
  fi
  return "$code"
}

execute_selected_steps() {
  local i any=0
  for i in "${!STEP_SELECTED[@]}"; do
    if [[ ${STEP_SELECTED[i]} -eq 1 ]]; then
      any=1
      break
    fi
  done
  if [[ $any -eq 0 ]]; then
    log_warn "未选择任何步骤"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    init_backup_root
  else
    BACKUP_ROOT="${SHELL_INIT_BACKUP_BASE:-$HOME/.cache/shell-init/backups}/dry-run"
  fi

  echo ""
  printf '%s==========================================%s\n' "$C_BOLD" "$C_RESET"
  echo "开始执行"
  printf '%s==========================================%s\n' "$C_BOLD" "$C_RESET"

  for i in "${!STEP_SELECTED[@]}"; do
    if [[ ${STEP_SELECTED[i]} -eq 1 ]]; then
      run_one_step "$i" || return $?
    fi
  done

  echo ""
  printf '%s==========================================%s\n' "$C_BOLD" "$C_RESET"
  echo "完成汇总"
  printf '%s==========================================%s\n' "$C_BOLD" "$C_RESET"
  if [[ ${#OK_STEPS[@]} -gt 0 ]]; then
    echo "成功:"
    local s
    for s in "${OK_STEPS[@]}"; do echo "  ✓ $s"; done
  fi
  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    echo "失败:"
    for s in "${FAILED_STEPS[@]}"; do echo "  ✗ $s"; done
  fi
  print_backup_summary
  echo ""
  echo "提示:"
  echo "  - 首次配置 zsh 后请重新打开终端或运行: zsh"
  echo "  - Neovim 全量重装请加: --force --steps=neovim"
  echo "  - mise 全局工具: packages/mise/config.toml（默认 node@lts + python@3.12）"
  echo "  - GUI 应用: 编辑 packages/Brewfile.apps 后 ./setup.sh --steps=apps"
  echo "  - AI Skills: 编辑 packages/skills/ 后 ./setup.sh --steps=skills"
  echo ""
}

print_help() {
  cat <<'EOF'
shell-init — macOS 开发环境初始化

无参数:
  ./setup.sh                 # 交互向导（推荐）

预设:
  ./setup.sh --preset=bootstrap   # 新机: brew + apps + 全部配置
  ./setup.sh --preset=config      # 仅同步配置
  ./setup.sh --preset=brew-only   # 仅 Homebrew + CLI Brewfile
  ./setup.sh --preset=apps-only   # 仅 GUI（Brewfile.apps）
  ./setup.sh --preset=fonts-only

自定义步骤:
  ./setup.sh --steps=brew,apps,zsh,neovim,mise

选项:
  --dry-run               只打印计划与动作，不改文件系统
  --yes / -y              跳过确认（适合 CI / 自动化）
  --force                 已安装也强制重装/覆盖
  --fail-fast             任一步失败即停止（默认继续并汇总）
  --mirror=tuna|ustc|ali|bfsu|official
                          Homebrew 镜像（默认 tuna；可持久化）
  --list-mirrors          列出镜像后退出
  --fonts=meslo,jetbrains 额外字体（默认不装；Meslo 在 Brewfile）
  --skills-targets=cursor,claude|all
                          覆盖自动识别（默认按 targets.conf 探测已装工具）
  doctor                  仅运行预检
  --help / -h

环境变量:
  GIT_USER_NAME / GIT_USER_EMAIL   仅在身份缺失或 --force / 向导确认时写入
  SKILL_TARGETS                    同 --skills-targets=

步骤 id: brew apps mise alacritty zsh pip tmux neovim fonts git skills
  （兼容别名: lazyvim/vim → neovim；skill → skills）

备份: ~/.cache/shell-init/backups/<timestamp>/
文档: ./README.md
EOF
}

run_doctor_cmd() {
  # shellcheck source=scripts/doctor.sh
  source "$SETUP_DIR/scripts/doctor.sh"
  doctor_main
}

parse_args() {
  local arg has_action=0
  local steps_csv=""
  local preset=""
  local use_wizard=0

  if [[ $# -eq 0 ]]; then
    use_wizard=1
  fi

  for arg in "$@"; do
    case "$arg" in
      --help|-h)
        print_help
        exit 0
        ;;
      doctor)
        run_doctor_cmd
        exit $?
        ;;
      --list-mirrors)
        list_mirrors
        exit 0
        ;;
      --dry-run)
        DRY_RUN=1
        export DRY_RUN
        ;;
      --yes|-y)
        ASSUME_YES=1
        export ASSUME_YES
        ;;
      --force)
        FORCE=1
        export FORCE
        ;;
      --fail-fast)
        CONTINUE_ON_ERROR=0
        export CONTINUE_ON_ERROR
        ;;
      --preset=*)
        preset="${arg#--preset=}"
        has_action=1
        ;;
      --steps=*)
        steps_csv="${arg#--steps=}"
        has_action=1
        ;;
      --mirror=*)
        BREW_MIRROR="${arg#--mirror=}"
        BREW_MIRROR="$(normalize_mirror_id "$BREW_MIRROR")" || exit 1
        BREW_MIRROR_SET=1
        export BREW_MIRROR BREW_MIRROR_SET
        ;;
      --fonts=*)
        FONT_KEYS="${arg#--fonts=}"
        export FONT_KEYS
        ;;
      --skills-targets=*)
        SKILL_TARGETS="${arg#--skills-targets=}"
        export SKILL_TARGETS
        ;;
      --apps=*|--list-apps|--brew-profile=*|--minimal*)
        log_err "已移除 apps.manifest / --apps=；请用 packages/Brewfile.apps + --steps=apps 或 --preset=apps-only"
        exit 1
        ;;
      *)
        log_err "未知参数: $arg"
        print_help
        exit 1
        ;;
    esac
  done

  if [[ $use_wizard -eq 1 ]]; then
    run_wizard
  else
    if [[ -n "$preset" ]]; then
      apply_preset "$preset"
    fi
    if [[ -n "$steps_csv" ]]; then
      local id
      local -a ids=()
      # If only steps given without preset, start clean
      if [[ -z "$preset" ]]; then
        registry_init_selection
      fi
      IFS=',' read -r -a ids <<<"$steps_csv"
      for id in "${ids[@]}"; do
        id="${id// /}"
        [[ -z "$id" ]] && continue
        select_step "$id" || exit 1
      done
      has_action=1
    fi
    if [[ $has_action -eq 0 ]]; then
      # Flags only (e.g. --dry-run alone) → treat as wizard-ish config default
      apply_preset config
    fi
    confirm_plan_if_needed
  fi

  execute_selected_steps
  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    exit 1
  fi
}

main() {
  parse_args "$@"
}

main "$@"
