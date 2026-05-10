#!/bin/bash

source ./util.sh

install_homebrew() {
    export HOMEBREW_INSTALL_FROM_API=1
    export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
    export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
    export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
    export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

uninstall_homebrew() {
    echo "Uninstalling Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    echo "Homebrew has been uninstalled."
}

reinstall_homebrew() {
    uninstall_homebrew
    install_homebrew
}

# 检查并安装 xcode-select
if ! command -v xcode-select >/dev/null 2>&1; then
    echo "正在安装 xcode-select..."
    xcode-select --install
fi

# 检查并安装 Homebrew
if command -v brew >/dev/null 2>&1; then
    echo "✓ Homebrew 已安装，跳过"
else
    echo "正在安装 Homebrew..."
    install_homebrew
fi

source .configrc

current_app=""
is_install_pkg=false

install_app() {
    install() {
        echo "正在安装 $current_app..."
        if [[ "$is_install_pkg" = true ]]; then
            brew install "$current_app"
        else
            brew install --cask "$current_app"
        fi
    }
    confirm "安装 $current_app ? (y/n): " install
}

# 检查应用是否已安装（cask）
is_cask_installed() {
    local app_name="$1"
    # 首先检查 brew 列表中是否有
    if brew list --cask 2>/dev/null | grep -q "^${app_name}$"; then
        return 0
    fi
    # 检查应用是否在 /Applications 目录中（针对 GUI 应用）
    # 将应用名称转换为可能的 .app 名称
    case "$app_name" in
        docker)
            [[ -d "/Applications/Docker.app" ]] && return 0
            ;;
        visual-studio-code)
            [[ -d "/Applications/Visual Studio Code.app" ]] && return 0
            ;;
        alacritty)
            [[ -d "/Applications/Alacritty.app" ]] && return 0
            ;;
        macpass)
            [[ -d "/Applications/MacPass.app" ]] && return 0
            ;;
        obsidian)
            [[ -d "/Applications/Obsidian.app" ]] && return 0
            ;;
        google-chrome)
            [[ -d "/Applications/Google Chrome.app" ]] && return 0
            ;;
        wechat)
            [[ -d "/Applications/WeChat.app" ]] && return 0
            ;;
        onedrive)
            [[ -d "/Applications/OneDrive.app" ]] && return 0
            ;;
        adrive)
            [[ -d "/Applications/阿里云盘.app" ]] && return 0
            ;;
        grammarly-desktop)
            [[ -d "/Applications/Grammarly Desktop.app" ]] && return 0
            ;;
        goldendict)
            [[ -d "/Applications/GoldenDict.app" ]] && return 0
            ;;
    esac
    return 1
}

# 检查应用是否已安装（package）
is_pkg_installed() {
    brew list 2>/dev/null | grep -q "^$1$"
}

install_apps() {
    echo "检查并安装应用程序..."
    for app in "${apps[@]}"; do
        current_app=$app
        if is_cask_installed "$app"; then
            echo "  ✓ $app 已安装，跳过"
        else
            install_app
        fi
    done

    echo ""
    echo "检查并安装软件包..."
    is_install_pkg=true
    for app in "${pkgs[@]}"; do
        current_app=$app
        if is_pkg_installed "$app"; then
            echo "  ✓ $app 已安装，跳过"
        else
            install_app
        fi
    done
}

install_apps
