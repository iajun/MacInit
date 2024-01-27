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

    read -p "$message (y/n): " response
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



# 定义函数创建软链接
create_symbolic_links() {
  local src_file dest_file dest_dir
  
  for link in "$@"; do
    src_file="${link%%:*}"
    dest_file="${link#*:}"

    # 获取目标目录
    dest_dir=$(dirname "$dest_file")

    # 确保目标目录存在
    mkdir -p "$dest_dir"

    # 如果软链接已存在，先移除
    [ -e "$dest_file" ] && rm "$dest_file"

    # 创建软链接
    ln -s "$src_file" "$dest_file"
  done
}

