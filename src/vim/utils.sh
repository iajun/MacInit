#!/bin/bash

DIR=$(dirname $0)

source $DIR/../util.sh

VERSION="nvim-macos-x86_64"

uninstall_nvim() {
	rm -rf /usr/local/share/nvim /usr/local/bin/nvim ~/.local/share/nvim ~/.config/nvim ~/.cache/nvim
}

install_nvim() {
	uninstall_nvim
	curl -LO https://github.com/neovim/neovim/releases/download/stable/$VERSION.tar.gz
	tar xzf $VERSION.tar.gz -C /usr/local/share
	mv /usr/local/share/$VERSION /usr/local/share/nvim
	ln -s /usr/local/share/nvim/bin/nvim /usr/local/bin/v
	rm -rf $VERSION.tar.gz
}

reinstall_nvim() {
	bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/uninstall.sh)
	echo 'Reinstalling Neovim...'
	install_nvim
}

uninstall_lvim() {
	rm -rf ~/.local/share/lvim ~/.local/share/lunarvim* ~/.config/lvim
}

install_lvim() {
	install_cargo() {
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
	}
	command_exists "cargo" install_cargo noop "Cargo is installed, reinstall it?"
	uninstall_lvim
	ln -s $DIR/lvim ~/.config/lvim
	LV_BRANCH='release-1.3/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)

	ln -s ~/.local/bin/lvim /usr/local/bin/v
}

install_lazynvim() {
	git clone https://github.com/LazyVim/starter ~/.config/nvim
	rm -rf ~/.config/nvim/.git
	ln -s $DIR/lazy ~/.config/nvim
}
