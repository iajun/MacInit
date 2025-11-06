function check_libpq() {
  # 检查 /usr/local/opt/libpq/bin 是否存在
  local libpq_path="/usr/local/opt/libpq/bin"
  if [[ ! -d "$libpq_path" ]]; then
    # 如果不存在，则运行 brew install libpq
    echo "libpq not found. Installing libpq..."
    if command -v brew >/dev/null 2>&1; then
      brew install libpq
    else
      echo "Warning: Homebrew not found. Please install libpq manually."
      return 1
    fi
  else
    export PATH="$libpq_path:$PATH"
  fi
}

# 检查 /Applications/DBeaver.app 是否存在并加载相应配置
if [[ -d "/Applications/DBeaver.app" ]]; then
  check_libpq
fi
