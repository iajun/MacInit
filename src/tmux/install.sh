#!/bin/bash

source ./util.sh

install_tmux() {
  brew install tmux
  cp ./tmux/tmux.conf ~/.config/tmux/tmux.conf
}

command_exists "tmux" noop install_tmux
