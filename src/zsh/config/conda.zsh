# ===== Conda 配置 =====
# 延迟初始化以提高启动速度
if [[ -f "$HOME/miniconda3/bin/conda" ]]; then
  __conda_setup="$('$HOME/miniconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"
  if [[ $? -eq 0 ]]; then
    eval "$__conda_setup"
  elif [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
  fi
  unset __conda_setup
fi

