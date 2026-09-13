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
      if [[ -n "${STEP_DESCS[i]:-}" ]]; then
        printf '      %s%s%s\n' "$C_DIM" "${STEP_DESCS[i]}" "$C_RESET"
      fi
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

selection_includes_brewish() {
  local i
  for i in "${!STEP_SELECTED[@]}"; do
    if [[ ${STEP_SELECTED[i]} -eq 1 ]]; then
      case "${STEP_IDS[i]}" in
        brew|apps) return 0 ;;
      esac
    fi
  done
  return 1
}

wizard_pick_mirror() {
  local choice
  echo ""
  log_info "Homebrew 镜像（装包时走哪个源）:"
  echo "  1) tuna     — 清华（默认，国内一般最快）"
  echo "  2) ustc     — 中科大"
  echo "  3) ali      — 阿里云"
  echo "  4) bfsu     — 北外"
  echo "  5) official — 官方（国外/代理环境）"
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

# List every step with number / id / short why
print_step_catalog() {
  local i num
  echo ""
  log_info "可选步骤（编号或 id 均可）:"
  echo ""
  for i in "${!STEP_IDS[@]}"; do
    num=$((i + 1))
    printf '  %2d) %-10s — %s\n' "$num" "${STEP_IDS[i]}" "${STEP_NAMES[i]}"
    printf '      %s%s%s\n' "$C_DIM" "${STEP_DESCS[i]}" "$C_RESET"
  done
  echo ""
  printf '%s示例:%s\n' "$C_DIM" "$C_RESET"
  echo "  5            → 只跑 zsh"
  echo "  5,8          → zsh + neovim"
  echo "  zsh,skills   → 用步骤 id（逗号分隔）"
  echo ""
}

# Parse "5" / "5,8" / "zsh,skills" / "5 zsh" into STEP_SELECTED
wizard_apply_step_tokens() {
  local raw="$1"
  local token idx num
  local -a tokens=()
  local any=0

  registry_init_selection
  # Allow commas and/or whitespace
  raw="${raw//,/ }"
  # shellcheck disable=SC2206
  tokens=($raw)

  if [[ ${#tokens[@]} -eq 0 ]]; then
    log_err "未输入任何步骤"
    return 1
  fi

  for token in "${tokens[@]}"; do
    token="${token// /}"
    [[ -z "$token" ]] && continue
    if [[ "$token" =~ ^[0-9]+$ ]]; then
      num=$((token))
      if [[ $num -lt 1 || $num -gt ${#STEP_IDS[@]} ]]; then
        log_err "编号超出范围: $token（有效 1–${#STEP_IDS[@]}）"
        return 1
      fi
      idx=$((num - 1))
      STEP_SELECTED[idx]=1
      any=1
    else
      select_step "$token" || return 1
      any=1
    fi
  done

  if [[ $any -eq 0 ]]; then
    log_err "未选中任何步骤"
    return 1
  fi

  # fonts alone: default meslo if user did not pass --fonts=
  local fonts_idx
  fonts_idx="$(step_index fonts)" || true
  if [[ -n "${fonts_idx:-}" && ${STEP_SELECTED[fonts_idx]} -eq 1 && -z "${FONT_KEYS:-}" ]]; then
    FONT_KEYS="meslo"
    export FONT_KEYS
    log_info "未指定 --fonts=，额外字体默认: meslo"
  fi
}

wizard_pick_steps() {
  local choice
  print_step_catalog
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    log_err "自定义步骤需要交互选择；请改用 --steps=id,id 或去掉 --yes"
    return 1
  fi
  while true; do
    read_prompt "输入要执行的步骤: " choice
    if [[ -z "${choice:-}" ]]; then
      log_warn "不能为空，请重新输入（或 Ctrl-C 退出）"
      continue
    fi
    if wizard_apply_step_tokens "$choice"; then
      return 0
    fi
    log_warn "请按示例重新输入"
  done
}

# Interactive wizard: preset bundle OR pick individual steps
run_wizard() {
  local rec choice preset
  print_banner
  echo ""
  rec="$(recommend_preset)"
  if [[ "$rec" == "bootstrap" ]]; then
    log_info "本机未检测到 Homebrew → 推荐「新机全量」"
  else
    log_info "本机已有 Homebrew → 推荐「仅同步配置」"
  fi
  echo ""
  echo "请选择要做什么:"
  echo ""
  echo "  1) 新机全量 (bootstrap)"
  echo "     装 Homebrew + GUI 应用，并同步全部配置。适合第一次初始化这台 Mac。"
  echo ""
  echo "  2) 仅同步配置 (config)"
  echo "     不装系统级软件包，只更新 mise / 终端 / 编辑器 / skills 等配置。"
  echo "     日常改完 packages/ 之后用这个。"
  echo ""
  echo "  3) 自定义 — 只跑某一个（或几个）功能"
  echo "     例如只要 zsh、只要 neovim、只要 skills。粒度最小，日常最常用。"
  echo ""
  echo "  4) 使用推荐 ($rec)"
  echo "     自动选上面的 1 或 2，不用自己判断。"
  echo ""
  echo "  q) 退出"
  echo ""

  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    choice="4"
    log_info "--yes: 使用推荐预设 $rec"
  else
    read_prompt "选择 [1/2/3/4/q]: " choice
  fi

  case "${choice:-4}" in
    1)
      preset="bootstrap"
      apply_preset "$preset"
      ;;
    2)
      preset="config"
      apply_preset "$preset"
      ;;
    3)
      preset="custom"
      wizard_pick_steps || exit 1
      ;;
    4|"")
      preset="$rec"
      apply_preset "$preset"
      ;;
    q|Q)
      log_info "已取消"
      exit 0
      ;;
    *)
      log_warn "无效选择，使用推荐: $rec"
      preset="$rec"
      apply_preset "$preset"
      ;;
  esac

  if selection_includes_brewish; then
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
