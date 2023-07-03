export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

export LC_CTYPE="en_US.UTF-8"
export PATH=$HOME/bin:/usr/local/bin:$PATH:$HOME/.local/bin:\"`python3 -m site --user-base`/bin\"

setopt prompt_subst
setopt append_history
setopt share_history
setopt extended_history
setopt histignorealldups
setopt histignorespace
setopt extended_glob
setopt longlistjobs
setopt nonomatch
setopt notify
setopt hash_list_all
setopt completeinword
setopt nohup
setopt auto_pushd
setopt nobeep
setopt pushd_ignore_dups
setopt noglobdots
setopt noshwordsplit
setopt autopushd pushdminus pushdsilent pushdtohome
setopt pushdignoredups
setopt autocd
setopt interactivecomments
stty -ixon

autoload -Uz colors && colors
autoload -Uz vcs_info
autoload -Uz compinit

HISTSIZE=1000000
SAVEHIST=9000000
HISTFILE=~/.config/zsh/zsh_history
TIMEFMT="'$fg[green]%J$reset_color' time: $fg[blue]%*Es$reset_color, cpu: $fg[blue]%P$reset_color"
REPORTTIME=10

zstyle ':completion:*' menu select
zstyle ':vcs_info:*' enable git svn
zstyle ':vcs_info:git*:*' get-revision true
zstyle ':vcs_info:git*:*' check-for-changes false
zstyle ':vcs_info:git*' formats "%8.8i %b "
zstyle ':vcs_info:git*' actionformats "%8.8i %b %F{red}%a %m%f "
zstyle ':vcs_info:git*' patch-format "%8.8p "
zstyle ':vcs_info:svn*:*' get-revision true
zstyle ':vcs_info:svn*:*' check-for-changes false
zstyle ':vcs_info:svn*' formats "%b %m "
zstyle ':vcs_info:svn*' actionformats "%b/%a %m "

COMPDUMPFILE=${COMPDUMPFILE:-${ZDOTDIR:-${HOME}}/.zcompdump}
compinit -d ${COMPDUMPFILE} || print 'Notice: no compinit available :('

function cd () {
    if (( ${#argv} == 1 )) && [[ -f ${1} ]]; then
        [[ ! -e ${1:h} ]] && return 1
        print "Correcting ${1} to ${1:h}"
        builtin cd ${1:h}
    else
        builtin cd "$@"
    fi
}

toggleSingleString() {
  LBUFFER=`echo $LBUFFER | sed "s/\(.*\) /\1 '/"`
  RBUFFER=`echo $RBUFFER | sed "s/\($\| \)/' /"`
  zle redisplay
}
zle -N toggleSingleString

toggleDoubleString() {
  LBUFFER=`echo $LBUFFER | sed 's/\(.*\) /\1 "/'`
  RBUFFER=`echo $RBUFFER | sed 's/\($\| \)/" /'`
  zle redisplay
}
zle -N toggleDoubleString

clearString() {
  LBUFFER=`echo $LBUFFER | sed 's/\(.*\)\('"'"'\|"\).*/\1\2/'`
  RBUFFER=`echo $RBUFFER | sed 's/.*\('"'"'\|"\)\(.*$\)/\1\2/'`
  zle redisplay
}
zle -N clearString

backward-kill-dir () {
    local WORDCHARS='*?-[]~=&;!#$%^(){}<>|_.'
    zle backward-kill-word
}
zle -N backward-kill-dir

backward-half-word () {
    local WORDCHARS='*?-[]~=&;!#$%^(){}<>|_.'
    zle backward-word
}
zle -N backward-half-word

forward-half-word () {
    local WORDCHARS='*?-[]~=&;!#$%^(){}<>|_.'
    zle forward-word
}
zle -N forward-half-word

function sudo-command-line () {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER != sudo\ * ]]; then
        BUFFER="sudo $BUFFER"
        CURSOR=$(( CURSOR+5 ))
    fi
}
zle -N sudo-command-line

function insert-datestamp () { LBUFFER+=${(%):-'%D{%Y-%m-%d}'}; }
zle -N insert-datestamp

function get-last-modified-file () {
	LAST_FILE=$(\ls -t1p | grep -v / | head -1)
	LBUFFER+=${(%):-$LAST_FILE}
}
zle -N get-last-modified-file

function jump_after_first_word () {
    local words
    words=(${(z)BUFFER})

    if (( ${#words} <= 1 )) ; then
        CURSOR=${#BUFFER}
    else
        CURSOR=${#${words[1]}}+1
    fi
}
zle -N jump_after_first_word

# Bindkeys
bindkey '\e[1;5C' forward-word
bindkey '\e[1;5D' backward-word
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search
bindkey "^xd" insert-datestamp
bindkey "^xa" sudo-command-line
bindkey "^x1" jump_after_first_word
bindkey "^x'" toggleSingleString
bindkey '^x"' toggleDoubleString
bindkey '^x;' clearString
bindkey '^xc' copy-prev-shell-word
bindkey '^xl' get-last-modified-file
bindkey '^[^?' backward-kill-dir
bindkey '\e[1;3D' backward-half-word
bindkey '\e[1;3C' forward-half-word

export ZSH=$HOME/.config/zsh/.oh-my-zsh
export ZSH_PLUGIN=$ZSH/custom/plugins

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"


autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '%b '
PROMPT='%F{green}%*%f %F{blue}%~%f %F{red}${vcs_info_msg_0_}%f$ '

plugins=(git npm brew macos z node docker)

source $ZSH/oh-my-zsh.sh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_DEFAULT_COMMAND='ag --nocolor --ignore node_modules -g ""'

export TERM=xterm-256color

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

