#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 确保 utils.sh 被正确加载
if [[ -f "$DIR/utils.sh" ]]; then
  source "$DIR/utils.sh"
else
  echo "⚠ 错误: 找不到 utils.sh 文件"
  exit 1
fi

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

# 显示 vim 配置选择菜单
show_vim_menu() {
  clear
  echo "=========================================="
  echo "选择要安装的 Vim 配置"
  echo "=========================================="
  echo ""
  echo "  [1] LunarVim - 功能丰富的 Neovim 配置"
  echo "  [2] LazyVim - 轻量级、快速的 Neovim 配置"
  echo "  [q] 跳过 Vim 配置安装"
  echo ""
}

# 安装 LunarVim
install_lunarvim() {
  echo ""
  echo "开始安装 LunarVim..."
  
  # 检查是否已安装 LazyVim，如果已安装则提示
  if [[ -d ~/.config/nvim ]] && [[ ! -L ~/.config/nvim ]]; then
    echo "ℹ 提示: 检测到已安装 LazyVim"
    echo "  LunarVim 使用 ~/.config/lvim，LazyVim 使用 ~/.config/nvim，不会冲突"
  fi
  
  command_exists "nvim" reinstall_nvim install_nvim "Neovim is installed, reinstall it?"
  command_exists "lvim" install_lvim install_lvim "Lunarvim is installed, reinstall it?"
  echo "✓ LunarVim 安装完成"
}

# 安装 LazyVim
install_lazyvim() {
  echo ""
  echo "开始安装 LazyVim..."
  command_exists "nvim" reinstall_nvim install_nvim "Neovim is installed, reinstall it?"
  
  # 检查是否已安装 LunarVim，如果已安装则提示冲突
  if command -v lvim >/dev/null 2>&1; then
    echo "⚠ 警告: 检测到已安装 LunarVim"
    read_prompt "LazyVim 和 LunarVim 使用不同的配置目录，不会冲突。是否继续安装 LazyVim? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "已取消安装 LazyVim"
      return
    fi
  fi
  
  # 提示用户将清理之前的配置
  if [[ -e ~/.config/nvim ]]; then
    echo "⚠ 警告: 检测到已存在的 ~/.config/nvim 配置"
    read_prompt "安装将彻底清理之前的配置并重新安装。是否继续? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "已取消安装 LazyVim"
      return
    fi
  fi
  
  # 安装 LazyVim
  # 确保 install_lazynvim 函数已加载
  if ! declare -f install_lazynvim >/dev/null; then
    echo "⚠ 错误: install_lazynvim 函数未找到，重新加载 utils.sh"
    source "$DIR/utils.sh"
  fi
  
  install_lazynvim
  echo "✓ LazyVim 安装完成"
}

# 主函数
main() {
  # 如果通过命令行参数指定，直接安装
  if [[ "$1" == "lunarvim" ]] || [[ "$1" == "lvim" ]]; then
    install_lunarvim
    return
  elif [[ "$1" == "lazyvim" ]] || [[ "$1" == "lazy" ]]; then
    install_lazyvim
    return
  fi
  
  # 交互式选择菜单
  while true; do
    show_vim_menu
    read_prompt "请选择 (1/2/q): " choice
    
    case "$choice" in
      1)
        install_lunarvim
        break
        ;;
      2)
        install_lazyvim
        break
        ;;
      q|Q)
        echo "跳过 Vim 配置安装"
        break
        ;;
      *)
        echo ""
        echo "⚠ 无效输入，请重新选择"
        read_prompt "按回车键继续..." _
        ;;
    esac
  done
}

# 运行主函数
main "$@"
