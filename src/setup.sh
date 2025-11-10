#!/bin/bash

# 获取脚本所在目录（保存为 SETUP_DIR，避免被其他脚本覆盖）
# 兼容 bash 和 zsh
if [[ -n "${BASH_SOURCE[0]}" ]]; then
  SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  # zsh 或其他 shell 的回退方案
  SETUP_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
cd "$SETUP_DIR" || exit 1

# 加载工具函数
source ./util.sh

# 定义步骤数组
declare -a STEP_NAMES=(
  "安装和配置 Homebrew"
  "配置 Alacritty"
  "安装和配置 zsh"
  "安装和配置 Vim (LunarVim/LazyVim)"
  "配置 pip"
  "安装字体和配置 tmux"
  "配置 Git"
)

# 定义步骤选择状态数组（0=未选择, 1=已选择）
declare -a STEP_SELECTED=(0 0 0 0 0 0 0)

# 兼容 bash 和 zsh 的 read 函数
read_prompt() {
  local prompt="$1"
  local var_name="$2"
  if [[ -n "${BASH_VERSION:-}" ]]; then
    # bash 使用 -p 选项
    read -p "$prompt" "$var_name"
  else
    # zsh 使用 "?prompt" 语法，需要直接使用变量名而不是引用
    eval "read \"?$prompt\" $var_name"
  fi
}

# 显示菜单
show_menu() {
  clear
  echo "=========================================="
  echo "选择要执行的安装步骤"
  echo "=========================================="
  echo ""
  local total_steps=${#STEP_NAMES[@]}
  for ((i=0; i<total_steps; i++)); do
    local checkbox="[ ]"
    if [[ ${STEP_SELECTED[$i]} -eq 1 ]]; then
      checkbox="[✓]"
    fi
    printf "  %s %d. %s\n" "$checkbox" $((i+1)) "${STEP_NAMES[$i]}"
  done
  echo ""
  echo "  [a] 全选/取消全选"
  echo "  [d] 完成选择并开始安装"
  echo "  [q] 退出"
  echo ""
}

# 切换步骤选择状态
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

# 全选/取消全选
toggle_all() {
  local all_selected=1
  for selected in "${STEP_SELECTED[@]}"; do
    if [[ $selected -eq 0 ]]; then
      all_selected=0
      break
    fi
  done
  
  local total_steps=${#STEP_SELECTED[@]}
  if [[ $all_selected -eq 1 ]]; then
    # 全部已选择，取消全选
    for ((i=0; i<total_steps; i++)); do
      STEP_SELECTED[$i]=0
    done
  else
    # 有未选择的，全选
    for ((i=0; i<total_steps; i++)); do
      STEP_SELECTED[$i]=1
    done
  fi
}

# 交互式选择菜单
interactive_menu() {
  while true; do
    show_menu
    read_prompt "请选择 (输入数字/a/d/q): " choice
    
    case "$choice" in
      [1-7])
        toggle_step "$choice"
        ;;
      a|A)
        toggle_all
        ;;
      d|D)
        # 检查是否至少选择了一个步骤
        local has_selection=0
        for selected in "${STEP_SELECTED[@]}"; do
          if [[ $selected -eq 1 ]]; then
            has_selection=1
            break
          fi
        done
        
        if [[ $has_selection -eq 0 ]]; then
          echo ""
          echo "⚠ 警告: 请至少选择一个步骤"
          read_prompt "按回车键继续..." _
        else
          break
        fi
        ;;
      q|Q)
        echo "退出安装"
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

# 步骤执行函数
step_install_homebrew() {
  echo ""
  echo "[1/7] 安装和配置 Homebrew..."
  source ./brew.sh
}

step_install_alacritty() {
  echo ""
  echo "[2/7] 配置 Alacritty..."
  mkdir -p ~/.config/alacritty
  if [[ -f ./alacritty/alacritty.toml ]]; then
    cp ./alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
    echo "✓ Alacritty 配置文件已安装"
  else
    echo "⚠ 警告: alacritty.toml 文件不存在"
  fi
}

step_install_zsh() {
  echo ""
  echo "[3/7] 安装和配置 zsh..."
  if [[ -f ./zsh/install.sh ]]; then
    # zsh/install.sh 使用 zsh，需要特殊处理
    if command -v zsh >/dev/null 2>&1; then
      zsh ./zsh/install.sh
    else
      echo "⚠ 警告: zsh 未安装，跳过 zsh 配置"
      echo "   可以稍后运行: zsh ./zsh/install.sh"
    fi
  else
    echo "⚠ 警告: zsh/install.sh 文件不存在"
  fi
}

step_install_vim() {
  echo ""
  echo "[4/7] 安装和配置 Vim (LunarVim/LazyVim)..."
  # 使用 bash 执行 install.sh，确保在正确的 shell 环境中运行
  bash ./vim/install.sh
}

step_install_pip() {
  echo ""
  echo "[5/7] 配置 pip..."
  if [[ -f ./pip/pip.conf ]]; then
    mkdir -p ~/.pip
    if [[ -f ~/.pip/pip.conf ]] && [[ ! -L ~/.pip/pip.conf ]]; then
      echo "⚠ 警告: ~/.pip/pip.conf 已存在，备份为 ~/.pip/pip.conf.bak"
      mv ~/.pip/pip.conf ~/.pip/pip.conf.bak
    fi
    ln -sf "$SETUP_DIR/pip/pip.conf" ~/.pip/pip.conf
    echo "✓ pip 配置文件已链接"
  else
    echo "⚠ 警告: pip/pip.conf 文件不存在"
  fi
}

step_install_fonts_tmux() {
  echo ""
  echo "[6/7] 安装字体和配置 tmux..."
  
  # 安装字体
  echo "  安装 Nerd Fonts..."
  if command -v brew >/dev/null 2>&1; then
    if brew list --cask font-meslo-lg-nerd-font >/dev/null 2>&1; then
      echo "  ✓ Meslo Nerd Font 已安装"
    else
      echo "  正在安装 Meslo Nerd Font..."
      brew install --cask font-meslo-lg-nerd-font
    fi
  else
    echo "  ⚠ 警告: Homebrew 未安装，跳过字体安装"
    echo "   可以稍后运行: source ./font-install.sh"
  fi
  
  # 安装和配置 tmux
  echo "  安装和配置 tmux..."
  source ./tmux/install.sh
}

step_install_git() {
  echo ""
  echo "[7/7] 配置 Git..."
  echo "=========================================="
  echo "配置 Git（需要在终端输入）"
  echo "=========================================="
  echo ""
  echo "请输入 Git 配置信息："
  read_prompt "Git 用户邮箱 (email): " GIT_USER_EMAIL
  read_prompt "Git 用户名 (name): " GIT_USER_NAME

  if [[ -n "$GIT_USER_EMAIL" ]] && [[ -n "$GIT_USER_NAME" ]]; then
    # 先运行 git/init.sh 配置代理和默认配置
    # 保存当前工作目录，因为其他脚本可能会改变它
    OLD_PWD="$PWD"
    source "$SETUP_DIR/git/init.sh"
    cd "$OLD_PWD" || cd "$SETUP_DIR" || exit 1
    
    # 然后添加用户信息到配置文件
    {
      echo ""
      echo "[user]"
      echo "	email = $GIT_USER_EMAIL"
      echo "	name = $GIT_USER_NAME"
    } >> $HOME/.gitconfig
    
    echo "✓ Git 配置完成"
  else
    echo "⚠ 警告: Git 用户信息未输入，跳过 Git 配置"
    echo "   可以稍后运行: source ./git/init.sh"
    echo "   然后手动配置: git config --global user.email 'your@email.com'"
    echo "                git config --global user.name 'Your Name'"
  fi
}

# 执行选中的步骤
execute_selected_steps() {
  echo ""
  echo "=========================================="
  echo "开始安装和配置开发环境工具"
  echo "=========================================="
  
  # 定义步骤执行函数数组
  declare -a STEP_FUNCTIONS=(
    "step_install_homebrew"
    "step_install_alacritty"
    "step_install_zsh"
    "step_install_vim"
    "step_install_pip"
    "step_install_fonts_tmux"
    "step_install_git"
  )
  
  # 执行选中的步骤
  local total_steps=${#STEP_SELECTED[@]}
  for ((i=0; i<total_steps; i++)); do
    if [[ ${STEP_SELECTED[$i]} -eq 1 ]]; then
      ${STEP_FUNCTIONS[$i]}
    fi
  done
  
  # 显示完成信息
  echo ""
  echo "=========================================="
  echo "安装和配置完成！"
  echo "=========================================="
  echo ""
  echo "已安装和配置的工具："
  for ((i=0; i<total_steps; i++)); do
    if [[ ${STEP_SELECTED[$i]} -eq 1 ]]; then
      echo "  ✓ ${STEP_NAMES[$i]}"
    fi
  done
  echo ""
  echo "提示："
  echo "  - 如果这是首次安装 zsh，请重新打开终端或运行: zsh"
  echo "  - 某些工具可能需要重启终端才能生效"
  echo ""
}

# 主程序
main() {
  interactive_menu
  execute_selected_steps
}

# 运行主程序
main
