#!/usr/bin/env bash
# Module: zsh + zinit (preserves env.zsh)

[[ -n "${_SHELL_INIT_MOD_ZSH_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_ZSH_LOADED=1

step_zsh_check() {
  if ! command -v zsh >/dev/null 2>&1; then
    echo "missing: zsh"
    return 1
  fi
  echo "ok: zsh=$(command -v zsh)"
  if [[ -d "$HOME/.local/share/zinit/zinit.git" ]]; then
    echo "ok: zinit present"
  else
    echo "missing: zinit"
  fi
  if [[ -f "$HOME/.config/zsh/.zshrc" ]]; then
    echo "ok: ~/.config/zsh/.zshrc"
  else
    echo "missing: ~/.config/zsh"
  fi
  return 0
}

step_zsh_run() {
  local pkg="$PACKAGES_DIR/zsh"
  local zinit_dir="$HOME/.local/share/zinit/zinit.git"
  local env_bak=""

  if ! command -v zsh >/dev/null 2>&1; then
    log_warn "zsh 未安装，跳过"
    return 1
  fi
  if [[ ! -d "$pkg" ]]; then
    log_err "packages/zsh 不存在"
    return 1
  fi

  assert_under_home "$HOME/.config/zsh" || return 1

  # Preserve local env.zsh across reset
  local had_env=0
  if [[ -f "$HOME/.config/zsh/env.zsh" && ! -L "$HOME/.config/zsh/env.zsh" ]]; then
    had_env=1
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_dry "保留现有 ~/.config/zsh/env.zsh"
    else
      env_bak="$(mktemp "${TMPDIR:-/tmp}/zsh-env.XXXXXX")"
      cp "$HOME/.config/zsh/env.zsh" "$env_bak"
    fi
  fi

  reset_config_dir "$HOME/.config/zsh"

  sync_config_files \
    "$pkg/.zshrc:$HOME/.config/zsh/.zshrc" \
    "$pkg/brew_tsinghua.zsh:$HOME/.config/zsh/brew_tsinghua.zsh" \
    "$pkg/pnpm.zsh:$HOME/.config/zsh/pnpm.zsh" \
    "$pkg/dbeaver.zsh:$HOME/.config/zsh/dbeaver.zsh" \
    "$pkg/.p10k.zsh:$HOME/.config/zsh/.p10k.zsh"

  sync_config_dir "$pkg/config" "$HOME/.config/zsh/config"

  if [[ $had_env -eq 1 ]]; then
    if [[ -n "$env_bak" && -f "$env_bak" ]]; then
      mv "$env_bak" "$HOME/.config/zsh/env.zsh"
      log_ok "已恢复本地 env.zsh"
    fi
  else
    init_config_file_if_missing "$pkg/env.example.zsh" "$HOME/.config/zsh/env.zsh"
  fi

  if [[ -f "$pkg/.zshenv" ]]; then
    sync_config_file "$pkg/.zshenv" "$HOME/.zshenv"
  fi

  # zinit: clone once unless --force
  if [[ -d "$zinit_dir" && "${FORCE:-0}" != "1" ]]; then
    log_ok "Zinit 已安装: $zinit_dir"
  else
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_dry "git clone zinit → $zinit_dir"
    else
      if [[ -d "$zinit_dir" ]]; then
        backup_path "$zinit_dir"
        rm -rf "$zinit_dir"
      fi
      log_info "安装 zinit..."
      mkdir -p "$(dirname "$zinit_dir")"
      git clone https://github.com/zdharma-continuum/zinit.git "$zinit_dir"
      log_ok "Zinit 已安装"
    fi
  fi
}
