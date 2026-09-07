#!/usr/bin/env bash
# Wizard / progress / confirmation UI.

[[ -n "${_SHELL_INIT_UI_LOADED:-}" ]] && return 0
_SHELL_INIT_UI_LOADED=1

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

print_banner() {
  printf '%s==========================================%s\n' "$C_BOLD" "$C_RESET"
  echo "shell-init — macOS 开发环境初始化"
  printf '%s==========================================%s\n' "$C_BOLD" "$C_RESET"
}

print_plan() {
  local i
  echo ""
  log_info "将执行的步骤:"
  for i in "${!STEP_SELECTED[@]}"; do
    if [[ ${STEP_SELECTED[i]} -eq 1 ]]; then
      echo "  • ${STEP_IDS[i]} — ${STEP_NAMES[i]}"
    fi
  done
  echo ""
  printf '%s  镜像: %s | CLI: Brewfile | GUI: Brewfile.apps%s\n' \
    "$C_DIM" "$BREW_MIRROR" "$C_RESET"
  if [[ -n "${FONT_KEYS:-}" ]]; then
    printf '%s  额外字体: %s%s\n' "$C_DIM" "$FONT_KEYS" "$C_RESET"
  fi
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '%s  模式: dry-run（不写文件系统）%s\n' "$C_DIM" "$C_RESET"
  fi
  if [[ "${FORCE:-0}" == "1" ]]; then
    printf '%s  模式: --force（强制重装/覆盖）%s\n' "$C_DIM" "$C_RESET"
  fi
  echo ""
}

# Recommend bootstrap if brew missing, else config
recommend_preset() {
  if ensure_brew_path 2>/dev/null; then
    echo "config"
  else
    echo "bootstrap"
  fi
}

wizard_pick_mirror() {
  local choice
  echo ""
  log_info "Homebrew 镜像:"
  echo "  1) tuna     — 清华（默认）"
  echo "  2) ustc     — 中科大"
  echo "  3) ali      — 阿里云"
  echo "  4) bfsu     — 北外"
  echo "  5) official — 官方"
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi
  read_prompt "选择镜像 [1-5，Enter=tuna]: " choice
  case "${choice:-1}" in
    1|"") BREW_MIRROR="tuna" ;;
    2) BREW_MIRROR="ustc" ;;
    3) BREW_MIRROR="ali" ;;
    4) BREW_MIRROR="bfsu" ;;
    5) BREW_MIRROR="official" ;;
    *)
      if normalize_mirror_id "$choice" >/dev/null 2>&1; then
        BREW_MIRROR="$(normalize_mirror_id "$choice")"
      else
        log_warn "无效镜像，使用 tuna"
        BREW_MIRROR="tuna"
      fi
      ;;
  esac
  export BREW_MIRROR
}

# Interactive wizard: sets preset / steps via apply_preset
run_wizard() {
  local rec choice preset
  print_banner
  echo ""
  rec="$(recommend_preset)"
  if [[ "$rec" == "bootstrap" ]]; then
    log_info "未检测到 Homebrew → 推荐预设: bootstrap（新机全量）"
  else
    log_info "已检测到 Homebrew → 推荐预设: config（仅同步配置）"
  fi
  echo ""
  echo "请选择:"
  echo "  1) bootstrap  — Homebrew + GUI 应用 + 全部配置"
  echo "  2) config     — 仅同步配置（mise/alacritty/zsh/tmux/neovim/pip）"
  echo "  3) 使用推荐 ($rec)"
  echo "  q) 退出"
  echo ""

  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    choice="3"
    log_info "--yes: 使用推荐预设 $rec"
  else
    read_prompt "选择 [1/2/3/q]: " choice
  fi

  case "${choice:-3}" in
    1) preset="bootstrap" ;;
    2) preset="config" ;;
    3|"") preset="$rec" ;;
    q|Q)
      log_info "已取消"
      exit 0
      ;;
    *)
      log_warn "无效选择，使用推荐: $rec"
      preset="$rec"
      ;;
  esac

  apply_preset "$preset"

  if [[ "$preset" == "bootstrap" || "$preset" == "brew-only" || "$preset" == "apps-only" ]]; then
    wizard_pick_mirror
  fi

  print_plan

  if [[ "${ASSUME_YES:-0}" != "1" ]]; then
    if ! confirm_yn "确认执行以上步骤?" "y"; then
      log_info "已取消"
      exit 0
    fi
  fi
}

confirm_plan_if_needed() {
  print_plan
  if [[ "${ASSUME_YES:-0}" == "1" || "${DRY_RUN:-0}" == "1" ]]; then
    return 0
  fi
  if ! confirm_yn "确认执行以上步骤?" "y"; then
    log_info "已取消"
    exit 0
  fi
}
