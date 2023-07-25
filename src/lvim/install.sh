#!/bin/bash

source ./util.sh

install_nvim() {
    rm -rf /usr/local/share/nvim ~/.local/share/nvim /usr/local/bin/nvim
    curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim-macos.tar.gz
    tar xzf nvim-macos.tar.gz -C /usr/local/share
    mv /usr/local/share/nvim-macos /usr/local/share/nvim
    ln -s /usr/local/share/nvim/bin/nvim /usr/local/bin/nvim
}

reinstall_nvim() {
    bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/uninstall.sh)
    echo 'Reinstalling Neovim...'
    install_nvim;
}

install_lvim() {
    install_cargo() {
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    }
    command_exists "cargo" install_cargo noop "Cargo is installed, reinstall it?"
    rm -rf /usr/local/bin/v ~/.local/share/lvim ~/.local/share/lunarvim*
    cp ./lvim/lvim/config.lua ~/.config/lvim/
    cp -r ./lvim/lvim/lua ~/.config/lvim/
    cp -r ./lvim/lvim/after ~/.config/lvim/after
    LV_BRANCH='release-1.3/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)

    ln -s ~/.local/bin/lvim /usr/local/bin/v
}

command_exists "nvim" reinstall_nvim install_nvim "Neovim is installed, reinstall it?"
command_exists "lvim" install_lvim install_lvim "Lunarvim is installed, reinstall it?"
