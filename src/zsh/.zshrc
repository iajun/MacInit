# 基本设置
setopt no_share_history
export TERM=xterm-256color

# zinit 配置（使用延迟加载和 turbo 模式）
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# 使用 turbo 模式和 wait 选项来延迟加载插件

zinit snippet https://gist.githubusercontent.com/hightemp/5071909/raw/
# zinit snippet https://gist.githubusercontent.com/DavidToca/3086571/raw/cabe5fef7d9e607c137b1e57d0e3aa1df05a16a8/git.plugin.zsh
zinit snippet https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/git/git.plugin.zsh
zi snippet OMZP::npm
zi snippet OMZP::docker

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
export PATH=$PATH:$HOME/.local/bin/
. "$HOME/.cargo/env"

alias v="lvim"
