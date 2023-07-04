#!/bin/bash

source .configrc

echo "$ZDOTDIR" 

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash \
    && echo 'export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"' >> $ZDOTDIR/.zshrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> $ZDOTDIR/.zshrc

source "$ZDOTDIR/.zshrc" && \
    nvm install 16 && \
    npm i -g yarn
