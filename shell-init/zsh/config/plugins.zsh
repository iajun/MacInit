# ===== Zinit 插件管理 =====
# 检查 zinit 目录是否存在
if [[ ! -d "$HOME/.local/share/zinit/zinit.git" ]]; then
  echo "警告: zinit 未安装，跳过插件加载"
  echo "请运行 install.sh 安装 zinit"
  return 1
fi

# 加载 zinit
source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"

# ===== 核心功能插件 =====
# zsh-autosuggestions - 自动建议
zinit light zsh-users/zsh-autosuggestions

# zsh-completions - 增强补全
zinit light zsh-users/zsh-completions

# NOTE: fzf-tab 会接管 Tab 补全交互；与 zsh-autocomplete 同时启用通常会冲突
# zinit light marlonrichert/zsh-autocomplete

# 自动括号配对
zinit light hlissner/zsh-autopair

# 实用工具插件
zinit ice as"program" pick"fzf" from"gh-r" wait'1' lucid
zinit light junegunn/fzf

# fzf-tab - 用 fzf 展示补全候选（底部列表 + 高亮 + 可搜索）
# 需要在启动时就可用（complete.zsh 会绑 Tab 到它），因此这里强制同步加载
zinit ice lucid
zinit light Aloxaf/fzf-tab

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
zinit light romkatv/powerlevel10k

# 语法高亮必须在最后加载（晚于会包装 line editor 的插件）
zinit light zsh-users/zsh-syntax-highlighting
