setopt no_share_history
CASE_SENSITIVE="true" # use case-sensitive completion.
ENABLE_CORRECTION="true"
export ZSH="$ZDOTDIR/.oh-my-zsh"
export LANG=en_US.UTF-8
export EDITOR='v'
export ADOTDIR=$HOME/.config/antigen
export ANTIGEN_LOG=$HOME/.config/antigen/antigen.log

bindkey "^[[1;3C" forward-word
bindkey "^[[1;3D" backward-word

source $ZDOTDIR/antigen.zsh

antigen bundle unixorn/autoupdate-antigen.zshplugin

antigen use oh-my-zsh

antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-history-substring-search
antigen bundle zsh-users/zsh-syntax-highlighting

antigen bundle akash329d/zsh-alias-finder
antigen bundle agkozak/zsh-z

antigen bundle git
antigen bundle z-shell/zsh-diff-so-fancy --branch=main

# antigen theme denysdovhan/spaceship-prompt
antigen theme robbyrussell

export ASDF_DIR=$HOME/.config/asdf
antigen bundle zimfw/asdf

# zstyle ':omz:update' mode auto # update automatically without asking
# source $ZSH/oh-my-zsh.sh

antigen apply

source $ZDOTDIR/brew_tsinghua.zsh

source $ZDOTDIR/env.zsh

source $ZDOTDIR/pnpm.zsh

export ICLOUD="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
