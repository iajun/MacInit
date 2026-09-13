#!/usr/bin/env bash
# Module: link shared Agent Skills into ~/.agents/skills
#
# Agents Skills 开放标准路径；Cursor / Claude / Codex / Copilot 等均可识别。
# Source of truth: packages/skills/<name>/SKILL.md
# Destination:     ~/.agents/skills/<name>

[[ -n "${_SHELL_INIT_MOD_SKILLS_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_SKILLS_LOADED=1

SKILLS_PKG_DIR="${PACKAGES_DIR}/skills"
SKILLS_DEST_REL=".agents/skills"
SKILLS_DEST_DIR="${HOME}/${SKILLS_DEST_REL}"

# 旧版多工具路径；每次 run 时清理，仅保留 ~/.agents/skills
SKILLS_LEGACY_RELS=(
  .cursor/skills
  .claude/skills
  .codex/skills
  .gemini/skills
  .copilot/skills
  .config/opencode/skills
  .codeium/windsurf/skills
  .continue/skills
  .config/agents/skills
  .gemini/antigravity/skills
  .kilocode/skills
  .roo/skills
  .augment/skills
  .codebuddy/skills
  .trae/skills
  .trae-cn/skills
  .junie/skills
  .config/goose/skills
  .openhands/skills
  .config/crush/skills
  .iflow/skills
  .kiro/skills
  .qwen/skills
  .pi/agent/skills
  .factory/skills
  .qoder/skills
  .zencoder/skills
  .neovate/skills
  .pochi/skills
  .openclaw/skills
  .cline/skills
  .kimi/skills
)

# List skill directories that contain SKILL.md
skills_list_dirs() {
  local d
  if [[ ! -d "$SKILLS_PKG_DIR" ]]; then
    return 0
  fi
  for d in "$SKILLS_PKG_DIR"/*/; do
    [[ -d "$d" ]] || continue
    [[ -f "${d}SKILL.md" ]] || continue
    printf '%s\n' "$(basename "$d")"
  done
}

link_skill_to_target() {
  local skill_name="$1"
  local dest_root="$2"
  local src="${SKILLS_PKG_DIR}/${skill_name}"
  local dest="${dest_root}/${skill_name}"

  assert_under_home "$dest" || return 1
  sync_config_dir "$src" "$dest"
}

# Remove legacy per-tool skills dirs (and empty parents created only for them)
skills_cleanup_legacy() {
  local rel path parent removed=0
  for rel in "${SKILLS_LEGACY_RELS[@]}"; do
    path="$HOME/$rel"
    [[ -e "$path" || -L "$path" ]] || continue
    assert_under_home "$path" || continue
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_dry "rm -rf $path"
    else
      rm -rf "$path"
      log_info "已清理旧路径: ~/$rel"
    fi
    removed=$((removed + 1))

    # 若父目录因此变空，一并删掉（不碰 .config / 非空工具目录）
    parent="$(dirname "$path")"
    while [[ "$parent" != "$HOME" && "$parent" != "/" ]]; do
      case "$parent" in
        "$HOME/.config") break ;;
      esac
      if [[ -d "$parent" ]] && [[ -z "$(ls -A "$parent" 2>/dev/null)" ]]; then
        if [[ "${DRY_RUN:-0}" == "1" ]]; then
          log_dry "rmdir $parent"
        else
          rmdir "$parent" 2>/dev/null || true
          log_info "已清理空目录: ~/${parent#"$HOME"/}"
        fi
        parent="$(dirname "$parent")"
      else
        break
      fi
    done
  done
  if [[ $removed -gt 0 ]]; then
    log_ok "已清理 ${removed} 个旧 skills 路径"
  fi
}

step_skills_check() {
  local name count=0 ok_links=0
  local -a skill_names=()

  if [[ ! -d "$SKILLS_PKG_DIR" ]]; then
    echo "missing: packages/skills"
    return 0
  fi

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    skill_names+=("$name")
    count=$((count + 1))
  done < <(skills_list_dirs)
  echo "ok: ${count} skill(s) in packages/skills → ~/${SKILLS_DEST_REL}"

  if [[ $count -eq 0 ]]; then
    echo "pending: no skills yet"
    return 0
  fi

  for name in "${skill_names[@]}"; do
    if [[ -L "${SKILLS_DEST_DIR}/${name}" ]]; then
      ok_links=$((ok_links + 1))
    fi
  done

  if [[ $ok_links -eq $count ]]; then
    echo "ok: ~/${SKILLS_DEST_REL} ($ok_links linked)"
  elif [[ $ok_links -gt 0 ]]; then
    echo "partial: ~/${SKILLS_DEST_REL} ($ok_links/$count linked)"
  else
    echo "missing: ~/${SKILLS_DEST_REL}"
  fi
  return 0
}

step_skills_run() {
  local name linked=0
  local -a skill_names=()

  if [[ ! -d "$SKILLS_PKG_DIR" ]]; then
    log_warn "技能目录不存在: $SKILLS_PKG_DIR"
    return 1
  fi

  skills_cleanup_legacy

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    skill_names+=("$name")
  done < <(skills_list_dirs)

  if [[ ${#skill_names[@]} -eq 0 ]]; then
    log_info "packages/skills 下尚无 SKILL.md；跳过链接（可先添加技能再重跑）"
    return 0
  fi

  assert_under_home "$SKILLS_DEST_DIR" || return 1
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "mkdir -p $SKILLS_DEST_DIR"
  else
    mkdir -p "$SKILLS_DEST_DIR"
  fi

  log_info "将链接 ${#skill_names[@]} 个技能 → ~/${SKILLS_DEST_REL}"
  for name in "${skill_names[@]}"; do
    link_skill_to_target "$name" "$SKILLS_DEST_DIR" || return 1
    linked=$((linked + 1))
  done

  log_ok "技能链接完成（${linked} 次链接操作）"
}
