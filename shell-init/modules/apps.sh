#!/usr/bin/env bash
# Module: GUI apps via packages/Brewfile.apps (standalone or via setup bootstrap)

[[ -n "${_SHELL_INIT_MOD_APPS_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_APPS_LOADED=1

step_apps_check() {
  local brewfile="$PACKAGES_DIR/Brewfile.apps"
  if [[ ! -f "$brewfile" ]]; then
    echo "missing: packages/Brewfile.apps"
    return 0
  fi
  echo "ok: Brewfile.apps=$brewfile"

  if ! ensure_brew_path 2>/dev/null; then
    echo "missing: brew (run brew step first)"
    return 0
  fi

  local line pkg
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    pkg="$(printf '%s\n' "$line" | sed -n 's/^cask[[:space:]]*"\([^"]*\)".*/\1/p')"
    [[ -z "$pkg" ]] && continue
    if brew list --cask "$pkg" >/dev/null 2>&1; then
      echo "ok: cask $pkg"
    else
      echo "missing: cask $pkg"
    fi
  done <"$brewfile"
  return 0
}

step_apps_run() {
  local brewfile
  brewfile="$(resolve_brewfile "$PACKAGES_DIR/Brewfile.apps")" || return 1

  if ! ensure_brew_path; then
    log_err "brew 不可用 — 请先运行: ./setup.sh --steps=brew"
    return 1
  fi
  apply_mirror_env "$BREW_MIRROR" || true

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "brew bundle install --file=$brewfile  (GUI apps)"
    return 0
  fi

  log_info "使用 Brewfile.apps: $brewfile"
  if ! brew bundle install --file="$brewfile"; then
    log_err "brew bundle (apps) 失败"
    return 1
  fi
  log_ok "GUI 应用安装完成（编辑 packages/Brewfile.apps 可增删）"
}
