#!/bin/zsh

# 同步 zsh 配置（自动检测新建/覆盖）
script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"

if [[ ! -f "$script_dir/../util.sh" ]]; then
  echo "Error: util.sh not found at $script_dir/../util.sh" >&2
  exit 1
fi

source "$script_dir/../util.sh"

config_files=(
  "$script_dir/.zshrc:$HOME/.config/zsh/.zshrc"
  "$script_dir/brew_tsinghua.zsh:$HOME/.config/zsh/brew_tsinghua.zsh"
  "$script_dir/pnpm.zsh:$HOME/.config/zsh/pnpm.zsh"
  "$script_dir/dbeaver.zsh:$HOME/.config/zsh/dbeaver.zsh"
  "$script_dir/.p10k.zsh:$HOME/.config/zsh/.p10k.zsh"
)

mkdir -p "$HOME/.config/zsh"
sync_config_files "${config_files[@]}"
init_config_file_if_missing "$script_dir/env.example.zsh" "$HOME/.config/zsh/env.zsh"
sync_config_dir "$script_dir/config" "$HOME/.config/zsh/config"

if [[ ! -f "$HOME/.zshenv" ]] && [[ -f "$script_dir/.zshenv" ]]; then
  echo "提示: ~/.zshenv 需手动配置，可参考: $script_dir/.zshenv"
fi

# zinit：仅首次克隆
zinit_dir="$HOME/.local/share/zinit/zinit.git"
if [[ ! -d "$zinit_dir" ]]; then
  echo "Installing zinit..."
  mkdir -p "$(dirname "$zinit_dir")"
  git clone https://github.com/zdharma-continuum/zinit.git "$zinit_dir"
  echo "Zinit installed successfully!"
else
  echo "Zinit already installed at $zinit_dir"
fi
