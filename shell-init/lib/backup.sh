#!/usr/bin/env bash
# Backup helpers: ~/.cache/shell-init/backups/<timestamp>/

[[ -n "${_SHELL_INIT_BACKUP_LOADED:-}" ]] && return 0
_SHELL_INIT_BACKUP_LOADED=1

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SHELL_INIT_CACHE="${SHELL_INIT_CACHE:-$HOME/.cache/shell-init}"
SHELL_INIT_BACKUP_BASE="${SHELL_INIT_BACKUP_BASE:-$SHELL_INIT_CACHE/backups}"

# Initialize BACKUP_ROOT for this run (idempotent within a process)
init_backup_root() {
  if [[ -n "${BACKUP_ROOT:-}" ]]; then
    return 0
  fi
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  BACKUP_ROOT="$SHELL_INIT_BACKUP_BASE/$ts"
  export BACKUP_ROOT
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "备份目录将为: $BACKUP_ROOT"
    return 0
  fi
  mkdir -p "$BACKUP_ROOT"
  log_info "备份目录: $BACKUP_ROOT"
}

# Backup a file or directory under BACKUP_ROOT, preserving a relative path key
# Usage: backup_path ~/.config/nvim [optional_label]
backup_path() {
  local src="$1"
  local label="${2:-}"
  local dest_name dest

  if [[ ! -e "$src" && ! -L "$src" ]]; then
    return 0
  fi

  init_backup_root

  if [[ -n "$label" ]]; then
    dest_name="$label"
  else
    # Strip leading $HOME/ for readable layout
    dest_name="${src/#$HOME\//}"
    dest_name="${dest_name/#\//}"
  fi

  dest="$BACKUP_ROOT/$dest_name"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "备份 $src → $dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -d "$src" && ! -L "$src" ]]; then
    cp -a "$src" "$dest"
  else
    cp -a "$src" "$dest"
  fi
  log_ok "已备份: $src → $dest"
}

print_backup_summary() {
  if [[ -z "${BACKUP_ROOT:-}" ]]; then
    return 0
  fi
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "dry-run 未写入备份；正式运行时备份目录: $BACKUP_ROOT"
    return 0
  fi
  if [[ -d "$BACKUP_ROOT" ]] && [[ -n "$(ls -A "$BACKUP_ROOT" 2>/dev/null || true)" ]]; then
    echo ""
    log_info "备份位置: $BACKUP_ROOT"
    log_info "手动恢复示例: cp -a \"$BACKUP_ROOT/.config/nvim\" ~/.config/nvim"
  fi
}
