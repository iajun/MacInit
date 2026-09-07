# ===== 补全系统初始化 =====
# compinit 必须在插件加载后执行（你在 .zshrc 里是先 plugins.zsh 再 complete.zsh，顺序正确）
autoload -Uz compinit

# 使用 zcompdump 缓存，加速启动
local _zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
mkdir -p "${_zcompdump:h}" 2>/dev/null
compinit -d "$_zcompdump"
unset _zcompdump

# ===== fzf-tab 交互（底部列表 + 高亮 + 可搜索）=====
zmodload -i zsh/complist

# fzf-tab 建议用一个字符串传给 fzf-command（否则可能被当成数组，导致奇怪的 permission denied）
zstyle ':fzf-tab:*' fzf-command 'fzf --height=40% --layout=reverse --border'

# 预览（可选）：在 macOS 上避免用 GNU ls 的 `--`
zstyle ':fzf-tab:complete:*' fzf-preview \
  '([[ -d "$realpath" ]] && command ls -la "$realpath" || sed -n "1,200p" "$realpath") 2>/dev/null'

# Tab 触发 fzf-tab（需要 fzf-tab 已加载并注册了该 widget）
bindkey '^I' fzf-tab-complete