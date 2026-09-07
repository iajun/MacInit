# Load Homebrew mirror env persisted by shell-init (./setup.sh --mirror=...)
# File: ~/.config/shell-init/brew-mirror.env
# Fallback: Tsinghua Tuna (same defaults as historical brew_tsinghua.zsh)

_si_mirror_env="${XDG_CONFIG_HOME:-$HOME/.config}/shell-init/brew-mirror.env"
if [[ -f "$_si_mirror_env" ]]; then
  # shellcheck disable=SC1090
  source "$_si_mirror_env"
else
  export HOMEBREW_INSTALL_FROM_API=1
  export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
fi
unset _si_mirror_env
