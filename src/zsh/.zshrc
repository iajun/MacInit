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

antigen theme denysdovhan/spaceship-prompt

export ASDF_DIR=$HOME/.config/asdf
antigen bundle zimfw/asdf
# antigen bundle kiurchv/asdf.plugin.zsh

# zstyle ':omz:update' mode auto      # update automatically without asking
# source $ZSH/oh-my-zsh.sh

antigen apply

source $ZDOTDIR/brew_tsinghua.zsh

source $ZDOTDIR/env.zsh

source $ZDOTDIR/pnpm.zsh

export PATH="/usr/local/opt/libpq/bin:$PATH"

# 检查 /Applications/DBeaver.app 是否存在并加载相应配置
dbeaver_app="/Applications/DBeaver.app"
if [[ -d "$dbeaver_app" ]]; then
    # DBeaver 应用程序存在，加载 env.zsh 文件
    if [[ -f "$ZDOTDIR/dbeaver.zsh" ]]; then
        source "$ZDOTDIR/dbeaver.zsh"
    fi
else
    # DBeaver 应用程序不存在的处理逻辑
    echo "DBeaver not found in $dbeaver_app. You may want to install it or adjust your configuration."
fi

