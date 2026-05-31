#!/bin/bash

# 获取脚本所在目录（保存为 SETUP_DIR，避免被其他脚本覆盖）
if [[ -n "${BASH_SOURCE[0]}" ]]; then
  SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SETUP_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
cd "$SETUP_DIR" || exit 1

source ./util.sh

declare -a STEP_NAMES=(
  "Homebrew"
  "Alacritty 配置"
  "zsh 配置"
  "pip 配置"
  "tmux 配置"
  "LazyVim 配置"
  "Vim 完整安装 (LazyVim/LunarVim)"
  "Nerd 字体"
  "Git 配置"
)

declare -a STEP_SELECTED=(0 0 0 0 0 0 0 0 0)

read_prompt() {
  local prompt="$1"
  local var_name="$2"
  if [[ -n "${BASH_VERSION:-}" ]]; then
    read -p "$prompt" "$var_name"
  else
    eval "read \"?$prompt\" $var_name"
  fi
}

show_menu() {
  clear
  echo "=========================================="
  echo "选择要同步/安装的项目"
  echo "（配置项自动检测：不存在则新建，已存在则覆盖并备份）"
  echo "=========================================="
  echo ""
  local total_steps=${#STEP_NAMES[@]}
  local i
  for ((i=0; i<total_steps; i++)); do
    local checkbox="[ ]"
    if [[ ${STEP_SELECTED[$i]} -eq 1 ]]; then
      checkbox="[✓]"
    fi
    printf "  %s %d. %s\n" "$checkbox" $((i+1)) "${STEP_NAMES[$i]}"
  done
  echo ""
  echo "  [a] 全选/取消全选"
  echo "  [d] 完成选择并开始"
  echo "  [q] 退出"
  echo ""
}

toggle_step() {
  local step_num=$1
  if [[ $step_num -ge 1 && $step_num -le ${#STEP_NAMES[@]} ]]; then
    local idx=$((step_num-1))
    if [[ ${STEP_SELECTED[$idx]} -eq 0 ]]; then
      STEP_SELECTED[$idx]=1
    else
      STEP_SELECTED[$idx]=0
    fi
  fi
}

toggle_all() {
  local all_selected=1
  local selected
  for selected in "${STEP_SELECTED[@]}"; do
    if [[ $selected -eq 0 ]]; then
      all_selected=0
      break
    fi
  done

  local total_steps=${#STEP_SELECTED[@]}
  local i
  if [[ $all_selected -eq 1 ]]; then
    for ((i=0; i<total_steps; i++)); do
      STEP_SELECTED[$i]=0
    done
  else
    for ((i=0; i<total_steps; i++)); do
      STEP_SELECTED[$i]=1
    done
  fi
}

interactive_menu() {
  while true; do
    show_menu
    read_prompt "请选择 (输入数字/a/d/q): " choice

    case "$choice" in
      [1-9])
        toggle_step "$choice"
        ;;
      a|A)
        toggle_all
        ;;
      d|D)
        local has_selection=0
        local selected
        for selected in "${STEP_SELECTED[@]}"; do
          if [[ $selected -eq 1 ]]; then
            has_selection=1
            break
          fi
        done

        if [[ $has_selection -eq 0 ]]; then
          echo ""
          echo "⚠ 请至少选择一项"
          read_prompt "按回车键继续..." _
        else
          break
        fi
        ;;
      q|Q)
        echo "退出"
        exit 0
        ;;
      *)
        echo ""
        echo "⚠ 无效输入，请重新选择"
        read_prompt "按回车键继续..." _
        ;;
    esac
  done
}

step_homebrew() {
  echo ""
  echo ">>> Homebrew"
  source ./brew.sh
}

step_sync_alacritty() {
  echo ""
  echo ">>> Alacritty 配置"
  mkdir -p ~/.config/alacritty
  if [[ -f ./alacritty/alacritty.toml ]]; then
    sync_config_file "$SETUP_DIR/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml
  else
    echo "⚠ 警告: alacritty.toml 不存在"
  fi
}

step_sync_zsh() {
  echo ""
  echo ">>> zsh 配置"
  if [[ -f ./zsh/install.sh ]]; then
    if command -v zsh >/dev/null 2>&1; then
      zsh ./zsh/install.sh
    else
      echo "⚠ 警告: zsh 未安装，跳过"
    fi
  else
    echo "⚠ 警告: zsh/install.sh 不存在"
  fi
}

step_sync_pip() {
  echo ""
  echo ">>> pip 配置"
  if [[ -f ./pip/pip.conf ]]; then
    mkdir -p ~/.pip
    sync_config_file "$SETUP_DIR/pip/pip.conf" ~/.pip/pip.conf
  else
    echo "⚠ 警告: pip/pip.conf 不存在"
  fi
}

step_sync_tmux() {
  echo ""
  echo ">>> tmux 配置"
  if [[ -f ./tmux/tmux.conf ]]; then
    mkdir -p ~/.config/tmux
    sync_config_file "$SETUP_DIR/tmux/tmux.conf" ~/.config/tmux/tmux.conf
  else
    echo "⚠ 警告: tmux.conf 不存在"
  fi
  if ! command -v tmux >/dev/null 2>&1; then
    read_prompt "未检测到 tmux，是否通过 Homebrew 安装? (y/n): " install_tmux
    if [[ "$install_tmux" =~ ^[Yy]$ ]]; then
      brew install tmux
    fi
  fi
}

step_sync_lazyvim() {
  echo ""
  echo ">>> LazyVim 配置"
  source ./vim/utils.sh
  sync_lazynvim
}

step_install_vim() {
  echo ""
  echo ">>> Vim 完整安装"
  bash ./vim/install.sh
}

step_install_fonts() {
  echo ""
  echo ">>> Nerd 字体"
  if command -v brew >/dev/null 2>&1; then
    if brew list --cask font-meslo-lg-nerd-font >/dev/null 2>&1; then
      echo "  ✓ Meslo Nerd Font 已安装"
    else
      echo "  正在安装 Meslo Nerd Font..."
      brew install --cask font-meslo-lg-nerd-font
    fi
  else
    echo "  ⚠ Homebrew 未安装，跳过。可稍后运行: source ./font-install.sh"
  fi
}

step_install_git() {
  echo ""
  echo ">>> Git 配置"
  bash ./git/init.sh
}

execute_selected_steps() {
  echo ""
  echo "=========================================="
  echo "开始执行"
  echo "=========================================="

  declare -a STEP_FUNCTIONS=(
    "step_homebrew"
    "step_sync_alacritty"
    "step_sync_zsh"
    "step_sync_pip"
    "step_sync_tmux"
    "step_sync_lazyvim"
    "step_install_vim"
    "step_install_fonts"
    "step_install_git"
  )

  local total_steps=${#STEP_SELECTED[@]}
  local i
  for ((i=0; i<total_steps; i++)); do
    if [[ ${STEP_SELECTED[$i]} -eq 1 ]]; then
      ${STEP_FUNCTIONS[$i]}
    fi
  done

  echo ""
  echo "=========================================="
  echo "完成"
  echo "=========================================="
  echo ""
  echo "已执行："
  for ((i=0; i<total_steps; i++)); do
    if [[ ${STEP_SELECTED[$i]} -eq 1 ]]; then
      echo "  ✓ ${STEP_NAMES[$i]}"
    fi
  done
  echo ""
  echo "提示："
  echo "  - 配置覆盖前已自动备份为 *.bak.<时间戳>"
  echo "  - 首次配置 zsh 后请重新打开终端或运行: zsh"
  echo ""
}

main() {
  interactive_menu
  execute_selected_steps
}

main
