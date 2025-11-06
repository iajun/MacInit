# Alacritty 配置

## 自动主题切换

Alacritty 可以根据 macOS 系统的深浅色模式自动切换主题。

### 使用方法

主题切换功能已集成到 zsh 配置中，使用 `alacritty-theme-switch` 函数：

```bash
# 手动切换主题（根据当前系统主题）
alacritty-theme-switch
```

### 工作原理

- 函数检测 macOS 系统深浅色模式
- 系统为深色模式时使用 `ayu_dark.toml`
- 系统为浅色模式时使用 `ayu_light.toml`
- 仅在主题需要变化时才更新配置文件

### 自动执行（可选）

如果希望在 shell 启动时自动切换主题，可以在 `.zshrc` 中添加：

```bash
# 在 shell 启动时自动切换 Alacritty 主题
alacritty-theme-switch
```

### 注意事项

- 确保 Alacritty 配置文件中启用了 `live_config_reload = true`（已启用）
- 主题切换后，Alacritty 会自动重新加载配置
- 函数定义在 `src/zsh/config/functions.zsh` 中

