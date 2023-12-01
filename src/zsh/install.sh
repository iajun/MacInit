#!/bin/bash

source .configrc
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cp ./zsh/.zshenv ~

if [[ -e $ZSH ]]; then
    rm -rf $ZSH
fi

original_config_path=~/.zshrc

echo $original_config_path

if [[ -e $original_config_path ]]; then
    rm $original_config_path
fi

echo "Installing zsh"
yes | bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
mkdir -p ~/.config/zsh
ln -s $DIR/.zshrc ~/.config/zsh/.zshrc

