#!/bin/bash

TEMP_DIR=$(mktemp -d)

git clone --depth=1 https://github.com/ryanoasis/nerd-fonts $TEMP_DIR
cd $TEMP_DIR
bash ./install.sh Meslo

rm -rf $TEMP_DIR
