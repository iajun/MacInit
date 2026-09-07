#!/usr/bin/env bash
# Module: Alacritty config + alacritty-theme clone

[[ -n "${_SHELL_INIT_MOD_ALACRITTY_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_ALACRITTY_LOADED=1

ALACRITTY_THEME_REPO="https://github.com/alacritty/alacritty-theme.git"
ALACRITTY_THEME_DIR="${HOME}/.config/alacritty/themes"

ensure_alacritty_themes() {
  assert_under_home "$ALACRITTY_THEME_DIR" || return 1

  if [[ -d "$ALACRITTY_THEME_DIR/.git" && "${FORCE:-0}" != "1" ]]; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_dry "更新 alacritty-theme: git -C $ALACRITTY_THEME_DIR pull --ff-only"
      return 0
    fi
    log_info "更新 alacritty-theme..."
    git -C "$ALACRITTY_THEME_DIR" pull --ff-only 2>/dev/null \
      || log_warn "alacritty-theme pull 失败（可稍后手动更新）"
    log_ok "主题目录已就绪: $ALACRITTY_THEME_DIR"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "clone alacritty-theme → $ALACRITTY_THEME_DIR"
    return 0
  fi

  if [[ -e "$ALACRITTY_THEME_DIR" || -L "$ALACRITTY_THEME_DIR" ]]; then
    backup_path "$ALACRITTY_THEME_DIR"
    rm -rf "$ALACRITTY_THEME_DIR"
  fi
  mkdir -p "$(dirname "$ALACRITTY_THEME_DIR")"
  log_info "克隆 alacritty-theme..."
  git clone --depth=1 "$ALACRITTY_THEME_REPO" "$ALACRITTY_THEME_DIR"
  log_ok "主题已安装: $ALACRITTY_THEME_DIR"
}

step_alacritty_check() {
  if [[ -f "$HOME/.config/alacritty/alacritty.toml" ]]; then
    echo "ok: alacritty.toml present"
  else
    echo "missing: ~/.config/alacritty/alacritty.toml"
  fi
  if [[ -d "$ALACRITTY_THEME_DIR" ]]; then
    echo "ok: themes dir present"
  else
    echo "missing: alacritty themes"
  fi
  return 0
}

step_alacritty_run() {
  local src="$PACKAGES_DIR/alacritty/alacritty.toml"
  assert_under_home ~/.config/alacritty || return 1

  # Preserve themes dir across reset: reset only if we need a clean conf dir,
  # but themes live under the same tree — so mkdir + sync file instead of full wipe.
  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    mkdir -p ~/.config/alacritty
  else
    log_dry "mkdir -p ~/.config/alacritty"
  fi

  if [[ -f "$src" ]]; then
    sync_config_file "$src" ~/.config/alacritty/alacritty.toml
  else
    log_warn "alacritty.toml 不存在: $src"
    return 1
  fi

  ensure_alacritty_themes
}
