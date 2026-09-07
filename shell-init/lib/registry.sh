#!/usr/bin/env bash
# Step registry: id ↔ name ↔ module functions.

[[ -n "${_SHELL_INIT_REGISTRY_LOADED:-}" ]] && return 0
_SHELL_INIT_REGISTRY_LOADED=1

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

declare -a STEP_IDS=(
  brew
  apps
  mise
  alacritty
  zsh
  pip
  tmux
  neovim
  fonts
  git
  skills
)

declare -a STEP_NAMES=(
  "Homebrew + CLI Brewfile"
  "GUI 应用 (Brewfile.apps)"
  "mise + node/python"
  "Alacritty 配置 + 主题"
  "zsh 配置 (zinit)"
  "pip 配置"
  "tmux 配置"
  "Neovim / LazyVim"
  "编程 / Nerd 字体（额外）"
  "Git 配置"
  "AI Skills（Cursor / Claude / Codex）"
)

# 1 = included in bootstrap preset by default
declare -a STEP_BOOTSTRAP=(
  1  # brew
  1  # apps
  1  # mise
  1  # alacritty
  1  # zsh
  1  # pip
  1  # tmux
  1  # neovim
  0  # fonts (meslo via Brewfile; extra only via --fonts=)
  1  # git
  1  # skills
)

declare -a STEP_SELECTED=()

registry_init_selection() {
  local i
  STEP_SELECTED=()
  for i in "${!STEP_IDS[@]}"; do
    STEP_SELECTED+=(0)
  done
}

step_index() {
  local id="$1" i
  for i in "${!STEP_IDS[@]}"; do
    if [[ "${STEP_IDS[i]}" == "$id" ]]; then
      echo "$i"
      return 0
    fi
  done
  return 1
}

select_step() {
  local id="$1"
  local idx
  # Compatibility aliases
  case "$id" in
    lazyvim|vim) id="neovim" ;;
    skill) id="skills" ;;
  esac
  idx="$(step_index "$id")" || {
    log_warn "未知步骤: $id"
    return 1
  }
  STEP_SELECTED[idx]=1
}

select_all_steps() {
  local i
  for i in "${!STEP_SELECTED[@]}"; do
    STEP_SELECTED[i]=1
  done
}

apply_preset() {
  local preset="$1"
  local i
  registry_init_selection
  case "$preset" in
    bootstrap|full|all)
      for i in "${!STEP_BOOTSTRAP[@]}"; do
        if [[ ${STEP_BOOTSTRAP[i]} -eq 1 ]]; then
          STEP_SELECTED[i]=1
        fi
      done
      # Also select fonts if user passed --fonts=
      if [[ -n "${FONT_KEYS:-}" ]]; then
        select_step fonts || true
      fi
      ;;
    config|dotfiles)
      select_step mise
      select_step alacritty
      select_step zsh
      select_step pip
      select_step tmux
      select_step neovim
      select_step skills
      ;;
    brew-only|brew)
      select_step brew
      ;;
    apps-only|apps)
      select_step apps
      ;;
    fonts-only|fonts)
      select_step fonts
      FONT_KEYS="${FONT_KEYS:-meslo}"
      ;;
    *)
      log_err "未知预设: $preset (bootstrap|config|brew-only|apps-only|fonts-only)"
      return 1
      ;;
  esac
}

load_modules() {
  local mod
  for mod in brew apps mise fonts alacritty zsh tmux neovim pip git skills; do
    # shellcheck disable=SC1090
    source "$SETUP_DIR/modules/${mod}.sh"
  done
}

# Doctor / check wrappers
step_check() {
  local id="$1"
  local fn="step_${id}_check"
  if declare -F "$fn" >/dev/null 2>&1; then
    "$fn"
  else
    return 0
  fi
}

step_run() {
  local id="$1"
  local fn="step_${id}_run"
  if declare -F "$fn" >/dev/null 2>&1; then
    "$fn"
  else
    log_err "未找到 step_${id}_run"
    return 1
  fi
}
