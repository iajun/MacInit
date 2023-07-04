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

source .configrc

current_app=""
is_install_pkg=false

install_app() {
    install() {
        echo "installing $current_app"
        if [[ "$is_install_pkg" = true ]]; then
            brew install "$current_app"
        else
            brew install --cask "$current_app"
        fi
    }
    confirm "Install app $current_app ? (y/n): " install
}


install_apps() {
    for app in "${apps[@]}"; do
        current_app=$app
        command_exists "brew list --cask $app" noop install_app app
    done

    is_install_pkg=true
    for app in "${pkgs[@]}"; do
        current_app=$app
        command_exists "brew list $app" noop install_app app
    done
}

install_apps
