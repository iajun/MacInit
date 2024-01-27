#!/bin/bash

# 获取脚本所在目录
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$script_dir/../util.sh"

link_files=(
  "$script_dir/.gitconfig:$HOME/.gitconfig"
)

create_symbolic_links "${link_files[@]}"
