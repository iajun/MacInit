# ===== 性能优化配置 =====
# 禁用不需要的 OMZ 功能以提高性能
zstyle ':omz:update' mode disabled   # 手动更新，避免自动检查
DISABLE_AUTO_TITLE="true"            # 禁用自动设置终端标题
DISABLE_UNTRACKED_FILES_DIRTY="true" # 在大型仓库中提高 git 状态检查速度
DISABLE_AUTO_UPDATE="true"           # 禁用 OMZ 自动更新
ZSH_AUTOSUGGEST_MANUAL_REBIND=1      # 提高自动建议性能

