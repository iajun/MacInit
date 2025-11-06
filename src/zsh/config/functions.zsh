# ===== 自定义函数 =====
# 清理 Zsh 内存
zsh-cleanup() {
  rehash
  builtin zle && zle -R # 重绘提示符
}

# antigen 手动更新函数
antigen-update() {
  # 清理缓存后更新
  rm -rf "$ADOTDIR/.cache" 2>/dev/null
  antigen update
}

