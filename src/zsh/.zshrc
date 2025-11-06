# ===== Zsh 配置文件主入口 =====
# 模块化配置加载器

# 定义安全加载函数
_safe_source() {
  [[ -f "$1" ]] && source "$1" 2>/dev/null || return 1
}

# ===== 核心配置模块（按顺序加载） =====
# 1. 性能优化配置（最先加载，影响后续所有配置）
_safe_source "$ZDOTDIR/config/performance.zsh"

# 2. 基础选项配置
_safe_source "$ZDOTDIR/config/options.zsh"

# 3. 环境变量配置
_safe_source "$ZDOTDIR/config/env.zsh"

# 4. 路径配置
_safe_source "$ZDOTDIR/config/path.zsh"

# 5. 按键绑定配置
_safe_source "$ZDOTDIR/config/keybindings.zsh"

# 6. 插件管理（Antigen）
_safe_source "$ZDOTDIR/config/plugins.zsh"

# ===== 延迟加载配置（插件加载后） =====
# 将性能影响较大的配置放在插件加载后
_safe_source "$ZDOTDIR/brew_tsinghua.zsh"
_safe_source "$ZDOTDIR/env.zsh"
_safe_source "$ZDOTDIR/pnpm.zsh"
_safe_source "$ZDOTDIR/dbeaver.zsh"
_safe_source "$ZDOTDIR/extra.zsh"

# 7. Conda 配置（延迟初始化以提高启动速度）
_safe_source "$ZDOTDIR/config/conda.zsh"

# 8. 自定义函数
_safe_source "$ZDOTDIR/config/functions.zsh"

# 9. 历史记录配置
_safe_source "$ZDOTDIR/config/history.zsh"

# 10. 自动切换 Alacritty 主题（根据系统深浅色模式）
# 静默执行，不影响启动速度
(alacritty-theme-switch &>/dev/null &)

# 清理临时函数
unset -f _safe_source
