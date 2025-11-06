# Zsh 配置模块说明

本目录包含模块化的 zsh 配置文件，每个文件负责特定的配置功能。

## 模块文件说明

### 核心配置模块（按加载顺序）

1. **performance.zsh** - 性能优化配置
   - 禁用 OMZ 自动更新
   - 禁用自动标题设置
   - 优化 git 状态检查
   - 优化自动建议性能

2. **options.zsh** - 基础选项配置
   - 历史记录设置
   - 补全选项
   - 命令校正设置

3. **env.zsh** - 环境变量配置
   - 语言设置
   - 编辑器设置
   - Antigen 相关变量
   - iCloud 路径

4. **path.zsh** - 路径配置
   - ASDF 目录
   - nvim 路径（如果存在）
   - miniconda 路径（如果存在）

5. **keybindings.zsh** - 按键绑定配置
   - Option + 方向键绑定

6. **plugins.zsh** - Antigen 插件管理
   - 插件加载和配置
   - 主题设置

### 延迟加载模块

7. **conda.zsh** - Conda 配置
   - Conda 初始化（延迟加载以提高启动速度）

8. **functions.zsh** - 自定义函数
   - `zsh-cleanup` - 清理 Zsh 内存
   - `antigen-update` - 手动更新 Antigen 插件

9. **history.zsh** - 历史记录配置
   - 历史记录压缩选项
   - 历史记录验证选项

## 使用说明

主配置文件 `.zshrc` 会自动按顺序加载这些模块。如果需要禁用某个模块，可以在 `.zshrc` 中注释掉对应的 `_safe_source` 行。

## 添加新模块

1. 在 `config/` 目录下创建新的 `.zsh` 文件
2. 在 `.zshrc` 中添加对应的 `_safe_source` 调用
3. 确保模块加载顺序符合依赖关系

