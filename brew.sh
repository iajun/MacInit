#!/bin/bash

source ./util.sh

install_homebrew() {
    export HOMEBREW_INSTALL_FROM_API=1
    export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
    export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
    export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
    export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

uninstall_homebrew() {
    echo "Uninstalling Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    echo "Homebrew has been uninstalled."
}

reinstall_homebrew() {
  uninstall_homebrew
  install_homebrew
}

command_exists "xcode-select" noop install_xcode_select
command_exists "brew" reinstall_homebrew install_homebrew "Do you want to reinstall Homebrew ?"

