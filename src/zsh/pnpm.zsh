# PNPM 配置
# 设置 PNPM 主目录并添加到 PATH（如果尚未存在）
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
