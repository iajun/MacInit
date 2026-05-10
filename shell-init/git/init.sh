#!/bin/bash

# 获取脚本所在目录
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Git 配置文件路径
gitconfig_file="$HOME/.gitconfig"

# 读取 default.txt 配置
default_config=""
if [[ -f "$script_dir/default.txt" ]]; then
    default_config=$(cat "$script_dir/default.txt")
fi

# 询问是否配置 SSH 代理
ssh_proxy_config=""
read -p "是否配置 SSH 代理 (将 https://github.com/ 替换为 ssh://git@github.com/) ? (y/n): " configure_ssh_proxy
if [[ "$configure_ssh_proxy" =~ ^[Yy]$ ]]; then
    ssh_proxy_config='[url "ssh://git@github.com/"]
    insteadOf = https://github.com/'
fi

# 询问是否配置 HTTP 代理
http_proxy_config=""
read -p "是否配置 HTTP 代理 (socks5://127.0.0.1:7890) ? (y/n): " configure_http_proxy
if [[ "$configure_http_proxy" =~ ^[Yy]$ ]]; then
    http_proxy_config='[http "https://github.com"]
    proxy = socks5://127.0.0.1:7890'
fi

# 询问用户信息
echo ""
echo "请输入 Git 用户信息："
read -p "Git 用户邮箱 (email): " GIT_USER_EMAIL
read -p "Git 用户名 (name): " GIT_USER_NAME

# 准备用户配置
user_config=""
if [[ -n "$GIT_USER_EMAIL" ]] && [[ -n "$GIT_USER_NAME" ]]; then
    user_config="[user]
	email = $GIT_USER_EMAIL
	name = $GIT_USER_NAME"
fi

# 合并所有配置并写入文件
{
    # 写入 default.txt 的配置
    if [[ -n "$default_config" ]]; then
        echo "$default_config"
    fi
    
    # 写入 SSH 代理配置
    if [[ -n "$ssh_proxy_config" ]]; then
        echo ""
        echo "; 配置 SSH 代理"
        echo "$ssh_proxy_config"
    fi
    
    # 写入 HTTP 代理配置
    if [[ -n "$http_proxy_config" ]]; then
        echo ""
        echo "; 配置 HTTP 代理"
        echo "$http_proxy_config"
    fi
    
    # 写入用户配置
    if [[ -n "$user_config" ]]; then
        echo ""
        echo "$user_config"
    fi
} > "$gitconfig_file"

echo "✓ Git 配置文件已写入: $gitconfig_file"
if [[ -n "$GIT_USER_EMAIL" ]] && [[ -n "$GIT_USER_NAME" ]]; then
    echo "✓ 用户信息已设置: $GIT_USER_NAME <$GIT_USER_EMAIL>"
else
    echo "⚠ 警告: 用户信息未输入，可稍后手动配置:"
    echo "   git config --global user.email 'your@email.com'"
    echo "   git config --global user.name 'Your Name'"
fi
