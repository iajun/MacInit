#!/usr/bin/env bash
# Module: mise config sync → ~/.config/mise/config.toml + install node/python
# Binary comes from Brewfile (brew "mise"); zsh activates via packages/zsh/config/path.zsh

[[ -n "${_SHELL_INIT_MOD_MISE_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_MISE_LOADED=1

_mise_ensure_cmd() {
  if command -v mise >/dev/null 2>&1; then
    return 0
  fi
  ensure_brew_path 2>/dev/null || true
  command -v mise >/dev/null 2>&1
}

_mise_tool_status() {
  local tool="$1"
  if ! _mise_ensure_cmd; then
    echo "missing: $tool (mise not installed)"
    return 0
  fi
  local ver
  ver="$(mise ls "$tool" --current --offline 2>/dev/null | awk 'NR==1 {print $2}')"
  if [[ -n "$ver" && "$ver" != "missing" ]]; then
    echo "ok: $tool=$ver"
  else
    echo "missing: $tool (run mise step / mise install)"
  fi
}

step_mise_check() {
  if command -v mise >/dev/null 2>&1; then
    echo "ok: mise=$(command -v mise)"
  elif ensure_brew_path 2>/dev/null && brew list mise >/dev/null 2>&1; then
    echo "ok: mise installed via brew (not on PATH yet)"
  else
    echo "missing: mise (install via brew step / Brewfile)"
  fi
  if [[ -f "$HOME/.config/mise/config.toml" ]]; then
    echo "ok: ~/.config/mise/config.toml"
  else
    echo "missing: ~/.config/mise/config.toml"
  fi
  _mise_tool_status node
  _mise_tool_status python
  return 0
}

step_mise_run() {
  local src="$PACKAGES_DIR/mise/config.toml"
  local dest="$HOME/.config/mise/config.toml"

  if [[ ! -f "$src" ]]; then
    log_err "packages/mise/config.toml 不存在"
    return 1
  fi

  assert_under_home "$HOME/.config/mise" || return 1

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "同步 mise config → $dest"
    if _mise_ensure_cmd; then
      log_dry "mise trust + mise install（node@lts, python@3.12）"
    else
      log_dry "mise binary 尚未安装（Brewfile 含 mise；先跑 brew 步骤）"
    fi
    return 0
  fi

  mkdir -p "$HOME/.config/mise"

  if [[ -f "$dest" && ! -L "$dest" && "${FORCE:-0}" != "1" ]]; then
    # Preserve local edits: only link if missing or already our symlink
    if [[ -L "$dest" ]]; then
      sync_config_file "$src" "$dest"
    else
      log_ok "保留本地 mise config: $dest（覆盖请加 --force）"
    fi
  else
    sync_config_file "$src" "$dest"
  fi

  if ! _mise_ensure_cmd; then
    log_warn "mise 命令尚未在 PATH（完成 brew 步骤后新开终端，或 eval \"\$(mise activate zsh)\"）"
    return 0
  fi

  # Trust this config path so mise does not prompt on first use
  mise trust "$dest" >/dev/null 2>&1 || true
  log_ok "mise $(mise --version 2>/dev/null | head -1)"

  log_info "安装全局工具: node@lts, python@3.12 …"
  if mise install; then
    log_ok "mise tools: $(mise ls --current --offline 2>/dev/null | awk '{print $1"@"$2}' | paste -sd ', ' - || echo node, python)"
  else
    log_err "mise install 失败（检查网络；可手动: mise install）"
    return 1
  fi
}
