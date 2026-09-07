# ===== 路径配置 =====
# 添加 nvim 到 PATH（如果存在）
[[ -d "/usr/local/share/nvim/bin" ]] && export PATH="/usr/local/share/nvim/bin:$PATH"

# 添加 miniconda 到 PATH（如果存在）
[[ -d "$HOME/miniconda3/bin" ]] && export PATH="$HOME/miniconda3/bin:$PATH"

[[ -d "/opt/homebrew/bin" ]] && export PATH="/opt/homebrew/bin:$PATH"

# mise - 多语言版本管理（替代 asdf）；需在 Homebrew PATH 之后激活
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi
