function check_libpq() {
  # 检查 /usr/local/opt/libpq/bin 是否存在
  libpq_path="/usr/local/opt/libpq/bin"
  if [[ ! -d "$libpq_path" ]]; then
    # 如果不存在，则运行 brew install libpq
    echo "libpq not found. Installing libpq..."
    brew install libpq
    # 可以在这里添加其他需要的配置
  else
    echo "hello"
    export PATH="$libpq_path:$PATH"
  fi
}

# 检查 /Applications/DBeaver.app 是否存在并加载相应配置
dbeaver_app="/Applications/DBeaver.app"
if [[ -d "$dbeaver_app" ]]; then
  check_libpq
else
  # DBeaver 应用程序不存在的处理逻辑
  echo "DBeaver not found in $dbeaver_app. You may want to install it or adjust your configuration."
fi
