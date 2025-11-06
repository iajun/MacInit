# ===== 按键绑定配置 =====
# 使用更现代的按键绑定语法
bindkey "^[[1;3C" forward-word  # Option + 右箭头
bindkey "^[[1;3D" backward-word # Option + 左箭头
bindkey "^E" end-of-line        # Ctrl + E 移动到行尾
bindkey "^A" beginning-of-line  # Ctrl + A 移动到行首
bindkey "^K" kill-line          # Ctrl + K 删除光标到行尾的内容
bindkey "^W" backward-kill-word # Ctrl + W 删除光标前的单词
bindkey "^U" kill-whole-line    # Ctrl + U 删除整行内容
bindkey "^Y" yank               # Ctrl + Y 粘贴剪贴板内容
bindkey "^P" history-substring-search-up # Ctrl + P 历史记录搜索向上
bindkey "^N" history-substring-search-down # Ctrl + N 历史记录搜索向下