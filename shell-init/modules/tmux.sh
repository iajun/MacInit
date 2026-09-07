#!/usr/bin/env bash
# Module: tmux config + ensure package

[[ -n "${_SHELL_INIT_MOD_TMUX_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_TMUX_LOADED=1

step_tmux_check() {
  if command -v tmux >/dev/null 2>&1; then
    echo "ok: tmux=$(command -v tmux)"
  else
    echo "missing: tmux"
  fi
  if [[ -f "$HOME/.config/tmux/tmux.conf" ]]; then
    echo "ok: ~/.config/tmux/tmux.conf"
  else
    echo "missing: tmux.conf"
  fi
  return 0
}

step_tmux_run() {
  local src="$PACKAGES_DIR/tmux/tmux.conf"
  assert_under_home ~/.config/tmux || return 1
  reset_config_dir ~/.config/tmux

  if [[ -f "$src" ]]; then
    sync_config_file "$src" ~/.config/tmux/tmux.conf
  else
    log_warn "tmux.conf 不存在: $src"
    return 1
  fi

  if command -v tmux >/dev/null 2>&1 && [[ "${FORCE:-0}" != "1" ]]; then
    log_ok "tmux 已安装"
    return 0
  fi

  if ensure_brew_path; then
    run_action "安装 tmux" brew install tmux
  else
    log_warn "未找到 tmux，且 Homebrew 不可用"
    return 1
  fi
}
