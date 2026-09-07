#!/usr/bin/env bash
# Symlink / reset helpers. Destructive ops go through backup.

[[ -n "${_SHELL_INIT_SYNC_LOADED:-}" ]] && return 0
_SHELL_INIT_SYNC_LOADED=1

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=backup.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backup.sh"

_remove_existing_dest() {
  local dest="$1"
  if [[ -L "$dest" || -e "$dest" ]]; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_dry "删除: $dest"
      return 0
    fi
    rm -rf "$dest"
    echo "  · 已删除原有: $dest"
  fi
}

# 删除整个配置目录后重建（破坏前备份）
reset_config_dir() {
  local dest="$1"
  assert_under_home "$dest" || return 1
  if [[ -e "$dest" || -L "$dest" ]]; then
    backup_path "$dest"
  fi
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "reset_config_dir $dest"
    return 0
  fi
  _remove_existing_dest "$dest"
  mkdir -p "$dest"
}

# 将仓库内配置以绝对路径软链接到目标（先备份再删再链）
sync_config_file() {
  local src="$1" dest="$2"
  if [[ ! -f "$src" ]]; then
    log_warn "源文件不存在，跳过: $src"
    return 1
  fi
  assert_under_home "$dest" || return 1
  src="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "链接 $dest → $src"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    # Idempotent: already correct symlink
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" && "${FORCE:-0}" != "1" ]]; then
      log_ok "已是目标链接: $dest"
      return 0
    fi
    backup_path "$dest"
    _remove_existing_dest "$dest"
  fi
  ln -sfn "$src" "$dest"
  echo "✓ 已链接: $dest → $src"
}

# 从模板复制本地可改文件（目标已存在则跳过，如 env.zsh）
init_config_file_if_missing() {
  local src="$1" dest="$2"
  if [[ ! -f "$src" ]]; then
    log_warn "模板不存在，跳过: $src"
    return 1
  fi
  assert_under_home "$dest" || return 1
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    if [[ -e "$dest" || -L "$dest" ]]; then
      log_dry "跳过 (已存在): $dest"
    else
      log_dry "初始化 $dest ← $src"
    fi
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "跳过 (已存在): $dest"
    return 0
  fi
  cp "$src" "$dest"
  echo "✓ 已初始化: $dest"
}

# 批量同步，参数格式为 src:dest
sync_config_files() {
  local entry src dest
  for entry in "$@"; do
    src="${entry%%:*}"
    dest="${entry#*:}"
    sync_config_file "$src" "$dest"
  done
}

# 将配置目录软链接到目标（先备份再删再链）
sync_config_dir() {
  local src="$1" dest="$2"
  if [[ ! -d "$src" ]]; then
    log_warn "源目录不存在，跳过: $src"
    return 1
  fi
  assert_under_home "$dest" || return 1
  src="$(cd "$src" && pwd)"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "链接目录 $dest → $src"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" && "${FORCE:-0}" != "1" ]]; then
      log_ok "已是目标目录链接: $dest"
      return 0
    fi
    backup_path "$dest"
    _remove_existing_dest "$dest"
  fi
  ln -sfn "$src" "$dest"
  echo "✓ 已链接目录: $dest → $src"
}
