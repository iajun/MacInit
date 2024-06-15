#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source $DIR/utils.sh

command_exists "nvim" reinstall_nvim install_nvim "Neovim is installed, reinstall it?"
command_exists "lvim" install_lvim install_lvim "Lunarvim is installed, reinstall it?"
