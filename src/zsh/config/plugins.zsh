# ===== Antigen 插件管理 =====
# 清理 antigen 缓存（解决重复安装问题）
if [[ -d "$ADOTDIR" ]]; then
  # 可选：清理缓存，但第一次运行时会重新下载
  # rm -rf "$ADOTDIR/.cache" 2>/dev/null
  :
fi

# 检查 antigen 文件是否存在
if [[ -f "$ZDOTDIR/antigen.zsh" ]]; then
  source "$ZDOTDIR/antigen.zsh"

  # 基础框架
  antigen use oh-my-zsh

  # 核心功能插件
  antigen bundle git
  antigen bundle zsh-users/zsh-autosuggestions
  antigen bundle zsh-users/zsh-completions
  antigen bundle zsh-users/zsh-history-substring-search
  antigen bundle zsh-users/zsh-syntax-highlighting

  # 实用工具插件
  antigen bundle akash329d/zsh-alias-finder
  antigen bundle agkozak/zsh-z
  antigen bundle z-shell/zsh-diff-so-fancy@main

  # 开发工具
  antigen bundle --no-antigen-update zimfw/asdf

  # 主题
  antigen theme robbyrussell

  # 禁用自动更新插件，手动更新以避免冲突
  # antigen bundle unixorn/autoupdate-antigen.zshplugin

  # 应用配置
  antigen apply
else
  echo "警告: antigen.zsh 未找到，跳过插件加载"
fi

