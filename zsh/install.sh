#!/bin/bash

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
cp ./zsh/.zshrc ~/.config/zsh/.zshrc
source ~/.config/zsh/.zshrc

echo "Installing zinit"
yes | bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
zinit self-update

