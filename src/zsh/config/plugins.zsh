# ===== Zinit 插件管理 =====
# 检查 zinit 目录是否存在
if [[ ! -d "$HOME/.local/share/zinit/zinit.git" ]]; then
  echo "警告: zinit 未安装，跳过插件加载"
  echo "请运行 install.sh 安装 zinit"
  return 1
fi

# 加载 zinit
source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"

# 核心功能插件
# zsh-autosuggestions - 自动建议
zinit light zsh-users/zsh-autosuggestions

# zsh-completions - 增强补全
zinit light zsh-users/zsh-completions
zinit light marlonrichert/zsh-autocomplete
zinit light zsh-users/zsh-syntax-highlighting

# zsh-history-substring-search - 历史记录搜索
zinit light zsh-users/zsh-history-substring-search

# 配置历史记录搜索的键绑定
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

# zsh-syntax-highlighting - 语法高亮（必须在最后加载）
zinit light zsh-users/zsh-syntax-highlighting

# 实用工具插件
# zsh-alias-finder - 别名查找
zinit light akash329d/zsh-alias-finder

# zsh-z - 快速跳转目录
zinit light agkozak/zsh-z

# 开发工具
# asdf - 版本管理工具
zinit light zimfw/asdf

# 常用别名插件（来自 oh-my-zsh，但不依赖 oh-my-zsh）
# 提供 l, ll, la, lsa 等常用别名
zinit snippet OMZ::plugins/common-aliases/common-aliases.plugin.zsh

# Git 插件（来自 oh-my-zsh，但不依赖 oh-my-zsh）
# 提供 git 别名和函数，包括 ggpush, ggpull 等
zinit snippet OMZ::plugins/git/git.plugin.zsh

# Git 快速补全插件（增强 git 命令补全）
zinit snippet OMZ::plugins/gitfast/gitfast.plugin.zsh

# 主题 - Powerlevel10k（功能强大且性能优秀的主题）
zinit ice depth=1
zinit light romkatv/powerlevel10k

