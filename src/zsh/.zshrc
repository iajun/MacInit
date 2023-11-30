# 基本设置
setopt no_share_history
export TERM=xterm-256color


# 自定义函数
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

# 绑定键

bindkey '\e[1;5C' forward-word     # Ctrl+Right Arrow
bindkey '\e[1;5D' backward-word    # Ctrl+Left Arrow
bindkey '^[[A' up-line-or-search   # Up Arrow
bindkey '^[[B' down-line-or-search # Down Arrow
bindkey "^xd" insert-datestamp     # Ctrl+d
bindkey "^xa" sudo-command-line    # Ctrl+a
bindkey "^x1" jump_after_first_word # Ctrl+1
bindkey "^x'" toggleSingleString   # Ctrl+'
bindkey '^x"' toggleDoubleString   # Ctrl+"
bindkey '^x;' clearString          # Ctrl+;
bindkey '^xc' copy-prev-shell-word # Ctrl+c
bindkey '^xl' get-last-modified-file # Ctrl+l
bindkey '^[^?' backward-kill-dir   # Ctrl+Backspace
bindkey '\e[1;3D' backward-half-word # Alt+Left Arrow
bindkey '\e[1;3C' forward-half-word  # Alt+Right Arrow

# 插件和 oh-my-zsh

source $ZSH/oh-my-zsh.sh
plugins=(aliases git gitignore npm docker history-substring-search)

# zinit 配置（使用延迟加载和 turbo 模式）
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# 使用 turbo 模式和 wait 选项来延迟加载插件
zinit ice wait"0a" as"program" from"gh-r" sbin"fzf"
zinit light junegunn/fzf-bin

# 其他插件也采用类似的方式进行延迟加载
zinit ice wait"0b" lucid
zinit for \
    zdharma-continuum/fast-syntax-highlighting \
    hlissner/zsh-autopair \
    zsh-users/zsh-history-substring-search \
    urbainvaes/fzf-marks \
    unixorn/docker-helpers.zshplugin \
    rupa/z

# 一些特定的插件可能需要立即加载
zinit light sindresorhus/pure
zinit light zsh-users/zsh-autosuggestions

# 环境变量和其他设置
export FZF_DEFAULT_COMMAND='ag --hidden --ignore "node_modules"'
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
