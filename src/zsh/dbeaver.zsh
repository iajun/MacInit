# 检查 /usr/local/opt/libpq/bin 是否存在
libpq_path="/usr/local/opt/libpq/bin"
if [[ ! -d "$libpq_path" ]]; then
    # 如果不存在，则运行 brew install libpq
    echo "libpq not found. Installing libpq..."
    brew install libpq
    # 可以在这里添加其他需要的配置
else
    echo "libpq found at $libpq_path"
    export PATH="$libpq_path:$PATH"
fi


