#!/usr/bin/env bash
# Module: pip.conf

[[ -n "${_SHELL_INIT_MOD_PIP_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_PIP_LOADED=1

step_pip_check() {
  if [[ -f "$HOME/.pip/pip.conf" ]]; then
    echo "ok: ~/.pip/pip.conf"
  else
    echo "missing: ~/.pip/pip.conf"
  fi
  return 0
}

step_pip_run() {
  local src="$PACKAGES_DIR/pip/pip.conf"
  if [[ ! -f "$src" ]]; then
    log_warn "pip.conf 不存在: $src"
    return 1
  fi
  assert_under_home ~/.pip/pip.conf || return 1
  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    mkdir -p ~/.pip
  else
    log_dry "mkdir -p ~/.pip"
  fi
  sync_config_file "$src" ~/.pip/pip.conf
}
