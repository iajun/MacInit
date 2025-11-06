#!/bin/bash

# 获取脚本所在目录（保存为 SETUP_DIR，避免被其他脚本覆盖）
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SETUP_DIR" || exit 1

# 加载工具函数
source ./util.sh

echo "=========================================="
echo "开始安装和配置开发环境工具"
echo "=========================================="

# 1. 安装和配置 Homebrew（必须先执行，因为其他工具依赖它）
echo ""
echo "[1/6] 安装和配置 Homebrew..."
source ./brew.sh

# 2. 配置 Alacritty
echo ""
echo "[2/6] 配置 Alacritty..."
mkdir -p ~/.config/alacritty
if [[ -f ./alacritty/alacritty.toml ]]; then
  cp ./alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
  echo "✓ Alacritty 配置文件已安装"
else
  echo "⚠ 警告: alacritty.toml 文件不存在"
fi

# 3. 安装和配置 zsh
echo ""
echo "[3/6] 安装和配置 zsh..."
if [[ -f ./zsh/install.sh ]]; then
  # zsh/install.sh 使用 zsh，需要特殊处理
  if command -v zsh >/dev/null 2>&1; then
    zsh ./zsh/install.sh
  else
    echo "⚠ 警告: zsh 未安装，跳过 zsh 配置"
    echo "   可以稍后运行: zsh ./zsh/install.sh"
  fi
else
  echo "⚠ 警告: zsh/install.sh 文件不存在"
fi

# 4. 安装和配置 lvim
echo ""
echo "[4/6] 安装和配置 LunarVim..."
source ./vim/install.sh

# 5. 配置 pip
echo ""
echo "[5/6] 配置 pip..."
if [[ -f ./pip/pip.conf ]]; then
  mkdir -p ~/.pip
  if [[ -f ~/.pip/pip.conf ]] && [[ ! -L ~/.pip/pip.conf ]]; then
    echo "⚠ 警告: ~/.pip/pip.conf 已存在，备份为 ~/.pip/pip.conf.bak"
    mv ~/.pip/pip.conf ~/.pip/pip.conf.bak
  fi
  ln -sf "$SETUP_DIR/pip/pip.conf" ~/.pip/pip.conf
  echo "✓ pip 配置文件已链接"
else
  echo "⚠ 警告: pip/pip.conf 文件不存在"
fi

# 6. 其他工具配置
echo ""
echo "[6/6] 配置其他工具..."

# 6.1 安装字体
echo "  安装 Nerd Fonts..."
if command -v brew >/dev/null 2>&1; then
  if brew list --cask font-meslo-lg-nerd-font >/dev/null 2>&1; then
    echo "  ✓ Meslo Nerd Font 已安装"
  else
    echo "  正在安装 Meslo Nerd Font..."
    brew install --cask font-meslo-lg-nerd-font
  fi
else
  echo "  ⚠ 警告: Homebrew 未安装，跳过字体安装"
  echo "   可以稍后运行: source ./font-install.sh"
fi

# 6.2 安装和配置 tmux
echo "  安装和配置 tmux..."
source ./tmux/install.sh

# 7. 配置 Git（交互式输入）
echo ""
echo "=========================================="
echo "配置 Git（需要在终端输入）"
echo "=========================================="
echo ""
echo "请输入 Git 配置信息："
read -p "Git 用户邮箱 (email): " GIT_USER_EMAIL
read -p "Git 用户名 (name): " GIT_USER_NAME

if [[ -n "$GIT_USER_EMAIL" ]] && [[ -n "$GIT_USER_NAME" ]]; then
  # 先运行 git/init.sh 配置代理和默认配置
  # 保存当前工作目录，因为其他脚本可能会改变它
  OLD_PWD="$PWD"
  source "$SETUP_DIR/git/init.sh"
  cd "$OLD_PWD" || cd "$SETUP_DIR" || exit 1
  
  # 然后添加用户信息到配置文件
  {
    echo ""
    echo "[user]"
    echo "	email = $GIT_USER_EMAIL"
    echo "	name = $GIT_USER_NAME"
  } >> $HOME/.gitconfig
  
  echo "✓ Git 配置完成"
else
  echo "⚠ 警告: Git 用户信息未输入，跳过 Git 配置"
  echo "   可以稍后运行: source ./git/init.sh"
  echo "   然后手动配置: git config --global user.email 'your@email.com'"
  echo "                git config --global user.name 'Your Name'"
fi

echo ""
echo "=========================================="
echo "安装和配置完成！"
echo "=========================================="
echo ""
echo "已安装和配置的工具："
echo "  ✓ Homebrew 和应用程序"
echo "  ✓ Alacritty"
echo "  ✓ zsh"
echo "  ✓ LunarVim"
echo "  ✓ pip"
echo "  ✓ Nerd Fonts"
echo "  ✓ tmux"
if [[ -n "$GIT_USER_EMAIL" ]] && [[ -n "$GIT_USER_NAME" ]]; then
  echo "  ✓ Git"
fi
echo ""
echo "提示："
echo "  - 如果这是首次安装 zsh，请重新打开终端或运行: zsh"
echo "  - 某些工具可能需要重启终端才能生效"
echo ""
