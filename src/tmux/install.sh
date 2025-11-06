#!/bin/bash

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

source ../util.sh

install_tmux() {
  brew install tmux
  mkdir -p ~/.config/tmux
  cp "$SCRIPT_DIR/tmux.conf" ~/.config/tmux/tmux.conf
}

command_exists "tmux" noop install_tmux
