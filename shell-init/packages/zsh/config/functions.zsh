# ===== 自定义函数 =====
# 清理 Zsh 内存
zsh-cleanup() {
  rehash
  builtin zle && zle -R # 重绘提示符
}

# zinit 手动更新函数
zinit-update() {
  # 更新所有插件
  zinit update
}

# zinit 更新特定插件
zinit-update-plugin() {
  if [[ -z "$1" ]]; then
    echo "用法: zinit-update-plugin <插件名>"
    echo "示例: zinit-update-plugin zsh-users/zsh-autosuggestions"
    return 1
  fi
  zinit update "$1"
}

# Git 相关函数
# 获取当前 git 分支名称（用于 ggpush 等别名）
git_current_branch() {
  local ref
  ref=$(command git symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # 不在 git 仓库中
    ref=$(command git rev-parse --short HEAD 2> /dev/null) || return
  fi
  echo ${ref#refs/heads/}
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

install-nerd-fonts() {
  brew install font-meslo-lg-nerd-font
}

# 安装并配置 Conda（使用清华镜像源）
install-conda() {
  local conda_install_dir="$HOME/miniconda3"
  local condarc_file="$HOME/.condarc"
  local arch
  local arch_suffix
  local installer_name
  local download_url
  local installer_path
  
  # 检测系统架构
  arch=$(uname -m)
  if [[ "$arch" == "arm64" ]]; then
    arch_suffix="osx-arm64"
  elif [[ "$arch" == "x86_64" ]]; then
    arch_suffix="osx-64"
  else
    echo "错误: 不支持的架构: $arch"
    return 1
  fi
  
  # 检查是否已安装 conda
  if [[ -f "$conda_install_dir/bin/conda" ]] || command -v conda >/dev/null 2>&1; then
    echo "Conda 已经安装，跳过安装步骤"
    echo "检查 ~/.condarc 配置..."
  else
    # 根据架构选择安装包
    if [[ "$arch" == "arm64" ]]; then
      installer_name="Miniconda3-latest-MacOSX-arm64.sh"
    else
      installer_name="Miniconda3-latest-MacOSX-x86_64.sh"
    fi
    
    # 构建下载 URL
    download_url="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/$installer_name"
    installer_path="/tmp/$installer_name"
    
    echo "检测到系统架构: $arch"
    echo "下载 Miniconda 安装包: $installer_name"
    
    # 下载安装包
    if ! curl -fsSL "$download_url" -o "$installer_path"; then
      echo "错误: 下载安装包失败"
      return 1
    fi
    
    echo "安装 Miniconda 到 $conda_install_dir"
    # 执行安装（静默模式，自动接受许可协议）
    bash "$installer_path" -b -p "$conda_install_dir"
    
    if [[ $? -ne 0 ]]; then
      echo "错误: Miniconda 安装失败"
      rm -f "$installer_path"
      return 1
    fi
    
    # 清理安装包
    rm -f "$installer_path"
    echo "Miniconda 安装完成"
    
    # 初始化 conda
    echo "初始化 Conda..."
    "$conda_install_dir/bin/conda" init zsh >/dev/null 2>&1
  fi
  
  # 配置 ~/.condarc
  echo "配置 ~/.condarc 使用清华镜像源..."
  
  # 创建或更新 ~/.condarc
  cat > "$condarc_file" <<EOF
ssl_verify: true
show_channel_urls: true

channels:
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/$arch_suffix
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free
  - defaults

default_channels:
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/$arch_suffix
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free

custom_channels:
  conda-forge: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
  pytorch: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
EOF
  
  echo "~/.condarc 配置完成（架构: $arch_suffix）"
  
  # 验证安装
  if [[ -f "$conda_install_dir/bin/conda" ]]; then
    echo "Conda 安装验证成功: $conda_install_dir/bin/conda"
    echo "请运行 'source ~/.zshrc' 或重新打开终端以使用 conda"
  elif command -v conda >/dev/null 2>&1; then
    echo "Conda 已可用"
    echo "运行 'conda info' 查看详细信息"
  else
    echo "警告: 无法验证 Conda 安装，请手动检查"
  fi
}