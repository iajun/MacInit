#!/bin/bash

mkdir -p ~/.config/alacritty
cp ./alacritty/alacritty.yml ~/.config/alacritty/alacritty.yml

export GIT_USER_EMAIL="iveoname@gmail.com"
export GIT_USER_NAME="Sharp Zhou"

source ./brew.sh
source ./tmux/install.sh
source ./lvim/install.sh
source ./nvm.sh

git config --global user.email $GIT_USER_EMAIL
git config --global user.name $GIT_USER_NAME

