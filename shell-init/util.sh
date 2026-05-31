#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

command_exists() {
    if command -v "$1" >/dev/null 2>&1; then
        # Command exists
        if [[ -n $2 ]]; then
            if [[ -n $4 ]]; then
                confirm "$4" "$2"
            else
                "$2"
            fi
        fi
    else
        # Command does not exist
        if [[ -n $3 ]]; then
            "$3"  # Execute the non-exists callback function
        fi
    fi
}

confirm() {
    local message=$1
    local callback=$2

    # 兼容 bash 和 zsh 的 read 函数
    local response
    if [[ -n "${BASH_VERSION:-}" ]]; then
        # bash 使用 -p 选项
        read -p "$message (y/n): " response
    else
        # zsh 使用 "?prompt" 语法
        read "?$message (y/n): " response
    fi
    
    echo $response
    case "$response" in
        [Yy])
            if [[ -n $callback ]]; then
                "$callback"  # Execute the callback function
            fi
            ;;
        *)
            echo "Confirmation declined"
            ;;
    esac
}

noop() {
    echo 'noop'
}

install() {
    local os_type=$(uname -s)

    if [[ $os_type == "Linux" ]]; then
        # Install package for Linux using the appropriate package manager
        if command -v apt-get >/dev/null 2>&1; then
            apt update
            apt-get install "$1"
        elif command -v yum >/dev/null 2>&1; then
            yum install "$1"
        else
            echo "Unsupported package manager. Manual installation required."
        fi
    elif [[ $os_type == "Darwin" ]]; then
        # Install package for macOS using Homebrew package manager
        if command -v brew >/dev/null 2>&1; then
            brew install "$1"
        else
            echo "Homebrew package manager not found. Please install it first."
        fi
    else
        echo "Unsupported operating system. Manual installation required."
    fi
}

uninstall() {
    local os_type=$(uname -s)

    if [[ $os_type == "Linux" ]]; then
        # Uninstall package for Linux using the appropriate package manager
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get remove "$1"
        elif command -v yum >/dev/null 2>&1; then
            sudo yum remove "$1"
        else
            echo "Unsupported package manager. Manual uninstallation required."
        fi
    elif [[ $os_type == "Darwin" ]]; then
        # Uninstall package for macOS using Homebrew package manager
        if command -v brew >/dev/null 2>&1; then
            brew uninstall "$1"
        else
            echo "Homebrew package manager not found. Please install it first."
        fi
    else
        echo "Unsupported operating system. Manual uninstallation required."
    fi
}


# 移除旧版软链接安装留下的符号链接
_remove_dest_if_symlink() {
  local dest="$1"
  if [[ -L "$dest" ]]; then
    rm "$dest"
  fi
}

# 同步单个配置文件：目标不存在则新建，已存在则备份后覆盖
sync_config_file() {
  local src="$1" dest="$2"
  if [[ ! -f "$src" ]]; then
    echo "⚠ 源文件不存在，跳过: $src" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  _remove_dest_if_symlink "$dest"
  if [[ -f "$dest" ]]; then
    cp "$dest" "${dest}.bak.$(date +%Y%m%d%H%M%S)"
    cp -f "$src" "$dest"
    echo "✓ 已同步 (覆盖): $dest"
  else
    cp "$src" "$dest"
    echo "✓ 已同步 (新建): $dest"
  fi
}

# 仅当目标不存在时从模板复制（不覆盖已有文件）
init_config_file_if_missing() {
  local src="$1" dest="$2"
  if [[ ! -f "$src" ]]; then
    echo "⚠ 模板不存在，跳过: $src" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  _remove_dest_if_symlink "$dest"
  if [[ -f "$dest" ]]; then
    echo "跳过 (已存在): $dest"
    return 0
  fi
  cp "$src" "$dest"
  echo "✓ 已初始化: $dest"
}

# 批量同步，参数格式为 src:dest
sync_config_files() {
  local entry src dest
  for entry in "$@"; do
    src="${entry%%:*}"
    dest="${entry#*:}"
    sync_config_file "$src" "$dest"
  done
}

# 同步配置目录：目标不存在则新建，已存在则备份后整目录覆盖
sync_config_dir() {
  local src="$1" dest="$2"
  if [[ ! -d "$src" ]]; then
    echo "⚠ 源目录不存在，跳过: $src" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  _remove_dest_if_symlink "$dest"
  if [[ -d "$dest" ]]; then
    cp -R "$dest" "${dest}.bak.$(date +%Y%m%d%H%M%S)"
    rm -rf "$dest"
    cp -R "$src" "$dest"
    echo "✓ 已同步目录 (覆盖): $dest"
  else
    cp -R "$src" "$dest"
    echo "✓ 已同步目录 (新建): $dest"
  fi
}
