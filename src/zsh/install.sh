#!/bin/bash

# 获取脚本所在目录
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$script_dir/../util.sh"

# 定义关联数组 link_files，包含每个文件的源路径和目标路径
link_files=(
  "$script_dir/.zshenv:$HOME/.zshenv"
  "$script_dir/.zshrc:$HOME/.config/zsh/.zshrc"
  "$script_dir/env.zsh:$HOME/.config/zsh/env.zsh"
  "$script_dir/brew_tsinghua.zsh:$HOME/.config/zsh/brew_tsinghua.zsh"
  "$script_dir/pnpm.zsh:$HOME/.config/zsh/pnpm.zsh"
)

create_symbolic_links "${link_files[@]}"

