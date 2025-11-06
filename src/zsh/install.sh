#!/bin/zsh

# 获取脚本所在目录
script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"

# 检查 util.sh 是否存在
if [[ ! -f "$script_dir/../util.sh" ]]; then
  echo "Error: util.sh not found at $script_dir/../util.sh" >&2
  exit 1
fi

source "$script_dir/../util.sh"

# 定义关联数组 link_files，包含每个文件的源路径和目标路径
link_files=(
  "$script_dir/.zshenv:$HOME/.zshenv"
  "$script_dir/.zshrc:$HOME/.config/zsh/.zshrc"
  "$script_dir/env.zsh:$HOME/.config/zsh/env.zsh"
  "$script_dir/brew_tsinghua.zsh:$HOME/.config/zsh/brew_tsinghua.zsh"
  "$script_dir/pnpm.zsh:$HOME/.config/zsh/pnpm.zsh"
  "$script_dir/dbeaver.zsh:$HOME/.config/zsh/dbeaver.zsh"
)

create_symbolic_links "${link_files[@]}"

# 链接 config 目录
config_src="$script_dir/config"
config_dest="$HOME/.config/zsh/config"
if [[ -d "$config_src" ]]; then
  # 确保目标目录的父目录存在
  mkdir -p "$(dirname "$config_dest")"
  # 如果链接已存在，先移除
  [[ -e "$config_dest" ]] && rm "$config_dest"
  # 创建目录软链接
  ln -s "$config_src" "$config_dest"
  echo "Linked config directory: $config_dest -> $config_src"
fi

