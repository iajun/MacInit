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

# Alacritty 主题切换函数（根据系统深浅色模式）
alacritty-theme-switch() {
  local config_file="$HOME/.config/alacritty/alacritty.toml"
  local themes_dir="~/.config/alacritty/themes/themes"
  local new_theme
  
  # 检测系统主题
  if [[ "$(uname)" == "Darwin" ]]; then
    local appearance=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
    if [[ "$appearance" == "Dark" ]]; then
      new_theme="ayu_dark.toml"
    else
      new_theme="ayu_light.toml"
    fi
  else
    new_theme="ayu_light.toml"
  fi
  
  # 检查配置文件是否存在
  if [[ ! -f "$config_file" ]]; then
    echo "Error: Alacritty config file not found at $config_file"
    return 1
  fi
  
  # 获取当前主题
  local current_theme=$(grep -E '^import = \[' "$config_file" | sed -E "s|.*/([^/]+)\.toml.*|\1.toml|")
  
  # 如果主题已经匹配，不需要更新
  if [[ "$current_theme" == "$new_theme" ]]; then
    return 0
  fi
  
  # 更新配置文件
  local new_import="import = [\"$themes_dir/$new_theme\"]"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|^import = \[.*\]|$new_import|" "$config_file"
  else
    sed -i "s|^import = \[.*\]|$new_import|" "$config_file"
  fi
  
  echo "Alacritty theme switched from $current_theme to $new_theme"
}

