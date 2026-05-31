#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$DIR/../util.sh"

VERSION="nvim-macos-x86_64"

uninstall_nvim() {
  rm -rf /usr/local/share/nvim /usr/local/bin/nvim /usr/local/bin/v ~/.local/share/nvim ~/.config/nvim ~/.cache/nvim
}

install_nvim() {
  uninstall_nvim
  curl -LO https://github.com/neovim/neovim/releases/download/stable/$VERSION.tar.gz
  tar xzf $VERSION.tar.gz -C /usr/local/share
  mv /usr/local/share/$VERSION /usr/local/share/nvim
  ln -sf /usr/local/share/nvim/bin/nvim /usr/local/bin/v
  rm -rf $VERSION.tar.gz
}

reinstall_nvim() {
  bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/uninstall.sh)
  echo 'Reinstalling Neovim...'
  install_nvim
}

uninstall_lvim() {
  rm -rf ~/.local/share/lvim ~/.local/share/lunarvim* ~/.config/lvim /usr/local/bin/v
}

install_lvim() {
  install_cargo() {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  }
  command_exists "cargo" install_cargo noop "Cargo is installed, reinstall it?"
  uninstall_lvim
  mkdir -p ~/.config
  cp -R "$DIR/lvim" ~/.config/lvim
  LV_BRANCH='release-1.3/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)

  ln -sf $(which nvim) /usr/local/bin/v
}

install_lazynvim() {
  # 在函数内部重新计算 VIM_DIR，确保使用正确的路径
  local VIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  echo "开始清理之前的 LazyVim 配置..."

  # 彻底清理 ~/.config/nvim 目录或软链接
  if [[ -e ~/.config/nvim ]]; then
    if [[ -L ~/.config/nvim ]]; then
      # 如果是软链接，先删除软链接
      rm -f ~/.config/nvim
      echo "  ✓ 已删除 ~/.config/nvim 软链接"
    elif [[ -d ~/.config/nvim ]]; then
      # 如果是目录，删除整个目录
      rm -rf ~/.config/nvim
      echo "  ✓ 已删除 ~/.config/nvim 目录"
    fi
  fi

  # 清理所有备份文件
  rm -rf ~/.config/nvim.*.backup
  rm -rf ~/.config/nvim.backup.*
  echo "  ✓ 已清理所有备份文件"

  # 清理 LazyVim 相关的缓存和数据
  rm -rf ~/.local/share/nvim
  rm -rf ~/.local/state/nvim
  rm -rf ~/.cache/nvim
  echo "  ✓ 已清理 LazyVim 缓存和数据"

  echo "清理完成，开始安装 LazyVim..."

  # 确保 ~/.config 目录存在
  mkdir -p ~/.config

  # 克隆 LazyVim starter
  git clone https://github.com/LazyVim/starter ~/.config/nvim
  rm -rf ~/.config/nvim/.git
  echo "  ✓ 已克隆 LazyVim starter"

  # 删除 starter 的默认 lua 目录，然后用项目的 lua 目录替换
  if [[ -d ~/.config/nvim/lua ]]; then
    rm -rf ~/.config/nvim/lua
    echo "  ✓ 已删除 LazyVim starter 的默认 lua 配置"
  fi

  _copy_lazyvim_project_files "$VIM_DIR"
  echo "✓ LazyVim 安装完成"
}

_copy_lazyvim_project_files() {
  local VIM_DIR="$1"

  if [[ -d "$VIM_DIR/lazy/lua" ]]; then
    sync_config_dir "$VIM_DIR/lazy/lua" ~/.config/nvim/lua
  else
    echo "  ⚠ 警告: 找不到项目 lua 配置目录: $VIM_DIR/lazy/lua"
  fi

  [[ -f "$VIM_DIR/lazy/init.lua" ]] && sync_config_file "$VIM_DIR/lazy/init.lua" ~/.config/nvim/init.lua
  [[ -f "$VIM_DIR/lazy/stylua.toml" ]] && sync_config_file "$VIM_DIR/lazy/stylua.toml" ~/.config/nvim/stylua.toml
  [[ -f "$VIM_DIR/lazy/lazyvim.json" ]] && sync_config_file "$VIM_DIR/lazy/lazyvim.json" ~/.config/nvim/lazyvim.json
}

sync_lazynvim() {
  local VIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ ! -d ~/.config/nvim ]]; then
    echo "⚠ ~/.config/nvim 不存在，请先选择「Vim 完整安装」"
    return 1
  fi
  _copy_lazyvim_project_files "$VIM_DIR"
  echo "✓ LazyVim 配置已同步"
}
