#!/usr/bin/env bash
# Module: link shared Agent Skills into detected AI tools (Cursor / Claude / Codex / …).
#
# Source of truth: packages/skills/<name>/SKILL.md
# Targets:         packages/skills/targets.conf
# Default:         auto-detect installed tools via targets.conf probe paths
# Override:        --skills-targets=cursor,claude  |  --skills-targets=all  (or SKILL_TARGETS)

[[ -n "${_SHELL_INIT_MOD_SKILLS_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_SKILLS_LOADED=1

SKILLS_PKG_DIR="${PACKAGES_DIR}/skills"
SKILLS_TARGETS_FILE="${SKILLS_PKG_DIR}/targets.conf"

skill_target_id()    { cut -d'|' -f1 <<<"$1"; }
skill_target_rel()   { cut -d'|' -f2 <<<"$1"; }
skill_target_label() { cut -d'|' -f3 <<<"$1"; }
skill_target_detect_field() {
  local row="$1" f
  f="$(cut -d'|' -f4 <<<"$row")"
  # cut returns the whole line when field missing on some systems if only 3 fields —
  # treat equal-to-row / empty as missing.
  if [[ -z "$f" || "$f" == "$row" ]]; then
    return 0
  fi
  printf '%s\n' "$f"
}

# Load non-comment rows from targets.conf → stdout as catalog lines
skills_load_catalog() {
  local line
  if [[ ! -f "$SKILLS_TARGETS_FILE" ]]; then
    log_warn "targets.conf 不存在: $SKILLS_TARGETS_FILE"
    return 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    # strip comments + trim
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf '%s\n' "$line"
  done <"$SKILLS_TARGETS_FILE"
}

find_skill_target_row() {
  local want="$1" row
  want="$(printf '%s' "$want" | tr '[:upper:]' '[:lower:]')"
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    if [[ "$(skill_target_id "$row")" == "$want" ]]; then
      printf '%s\n' "$row"
      return 0
    fi
  done < <(skills_load_catalog)
  return 1
}

# Resolve detect spec for a catalog row (* | paths | default=parent of skills dir)
skills_detect_spec() {
  local row="$1" rel spec
  rel="$(skill_target_rel "$row")"
  spec="$(skill_target_detect_field "$row" || true)"
  if [[ -z "$spec" ]]; then
    spec="$(dirname "$rel")"
  fi
  printf '%s\n' "$spec"
}

# True if any probe path / command indicates the tool is present
skills_target_detected() {
  local row="$1"
  local spec item path
  spec="$(skills_detect_spec "$row")"
  if [[ "$spec" == "*" ]]; then
    return 0
  fi
  local -a items=()
  IFS=',' read -r -a items <<<"$spec"
  for item in "${items[@]}"; do
    item="${item// /}"
    [[ -z "$item" ]] && continue
    case "$item" in
      cmd:*)
        command -v "${item#cmd:}" >/dev/null 2>&1 && return 0
        ;;
      /*)
        [[ -e "$item" ]] && return 0
        ;;
      *)
        path="$HOME/$item"
        [[ -e "$path" ]] && return 0
        ;;
    esac
  done
  return 1
}

# Deduplicate ids while preserving order (bash 3.2 compatible)
skills_unique_ids() {
  local id seen="|"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    case "$seen" in
      *"|$id|"*) continue ;;
    esac
    seen="${seen}${id}|"
    printf '%s\n' "$id"
  done
}

# Resolve which target ids to use
#   SKILL_TARGETS empty → auto-detect
#   SKILL_TARGETS=all   → every catalog entry
#   SKILL_TARGETS=a,b   → explicit list
skills_selected_ids() {
  local -a keys=()
  local id row
  if [[ -n "${SKILL_TARGETS:-}" ]]; then
    if [[ "$(printf '%s' "$SKILL_TARGETS" | tr '[:upper:]' '[:lower:]')" == "all" ]]; then
      while IFS= read -r row; do
        [[ -z "$row" ]] && continue
        printf '%s\n' "$(skill_target_id "$row")"
      done < <(skills_load_catalog) | skills_unique_ids
      return 0
    fi
    IFS=',' read -r -a keys <<<"$SKILL_TARGETS"
    for id in "${keys[@]}"; do
      id="${id// /}"
      id="$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')"
      [[ -z "$id" ]] && continue
      printf '%s\n' "$id"
    done | skills_unique_ids
    return 0
  fi

  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    if skills_target_detected "$row"; then
      printf '%s\n' "$(skill_target_id "$row")"
    fi
  done < <(skills_load_catalog) | skills_unique_ids
}

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

# Avoid linking the same dest_root twice when catalog shares a path (e.g. amp + kimi)
skills_dest_already_done() {
  local dest="$1"
  local seen="$2"
  case "|$seen|" in
    *"|$dest|"*) return 0 ;;
    *) return 1 ;;
  esac
}

step_skills_check() {
  local name count=0 id row rel skill_dest ok_links=0 mode
  local -a ids=()
  local -a skill_names=()
  local catalog_n=0 detected_n=0

  if [[ ! -d "$SKILLS_PKG_DIR" ]]; then
    echo "missing: packages/skills"
    return 0
  fi

  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    catalog_n=$((catalog_n + 1))
    if skills_target_detected "$row"; then
      detected_n=$((detected_n + 1))
    fi
  done < <(skills_load_catalog)

  if [[ -n "${SKILL_TARGETS:-}" ]]; then
    mode="override:${SKILL_TARGETS}"
  else
    mode="auto-detect"
  fi
  echo "ok: catalog=${catalog_n} detected=${detected_n} mode=${mode}"

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    skill_names+=("$name")
    count=$((count + 1))
  done < <(skills_list_dirs)
  echo "ok: ${count} skill(s) in packages/skills"

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    ids+=("$id")
  done < <(skills_selected_ids)

  if [[ ${#ids[@]} -eq 0 ]]; then
    echo "pending: no targets selected (install an AI tool or --skills-targets=)"
    return 0
  fi

  if [[ $count -eq 0 ]]; then
    for id in "${ids[@]}"; do
      echo "pending: $id (no skills yet)"
    done
    return 0
  fi

  for id in "${ids[@]}"; do
    if ! row="$(find_skill_target_row "$id")"; then
      echo "unknown target: $id"
      continue
    fi
    rel="$(skill_target_rel "$row")"
    ok_links=0
    for name in "${skill_names[@]}"; do
      skill_dest="$HOME/$rel/$name"
      if [[ -L "$skill_dest" ]]; then
        ok_links=$((ok_links + 1))
      fi
    done
    if [[ $ok_links -eq $count ]]; then
      echo "ok: $id → ~/$rel ($ok_links linked)"
    elif [[ $ok_links -gt 0 ]]; then
      echo "partial: $id → ~/$rel ($ok_links/$count linked)"
    else
      echo "missing: $id (~/$rel)"
    fi
  done
  return 0
}

step_skills_run() {
  local name id row rel dest_root label linked=0 missing_target=0
  local -a skill_names=()
  local -a target_ids=()
  local done_dests=""

  if [[ ! -d "$SKILLS_PKG_DIR" ]]; then
    log_warn "技能目录不存在: $SKILLS_PKG_DIR"
    return 1
  fi

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    skill_names+=("$name")
  done < <(skills_list_dirs)

  if [[ ${#skill_names[@]} -eq 0 ]]; then
    log_info "packages/skills 下尚无 SKILL.md；跳过链接（可先添加技能再重跑）"
    return 0
  fi

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    target_ids+=("$id")
  done < <(skills_selected_ids)

  if [[ ${#target_ids[@]} -eq 0 ]]; then
    if [[ -n "${SKILL_TARGETS:-}" ]]; then
      log_warn "未匹配任何 skills 目标（检查 --skills-targets= / targets.conf）"
      return 1
    fi
    log_info "未检测到已安装的 AI 工具配置目录；跳过 skills 链接"
    log_info "安装 Cursor/Claude/Codex 等后重跑，或: --skills-targets=all"
    return 0
  fi

  if [[ -n "${SKILL_TARGETS:-}" ]]; then
    log_info "将链接 ${#skill_names[@]} 个技能 → ${#target_ids[@]} 个目标（手动: ${SKILL_TARGETS}）"
  else
    log_info "将链接 ${#skill_names[@]} 个技能 → ${#target_ids[@]} 个已识别目标: ${target_ids[*]}"
  fi

  for id in "${target_ids[@]}"; do
    if ! row="$(find_skill_target_row "$id")"; then
      log_warn "未知 skills 目标: $id（见 packages/skills/targets.conf）"
      missing_target=1
      continue
    fi
    rel="$(skill_target_rel "$row")"
    label="$(skill_target_label "$row")"
    dest_root="$HOME/$rel"

    if skills_dest_already_done "$dest_root" "$done_dests"; then
      log_info "跳过重复路径: $label (~/$rel)"
      continue
    fi
    done_dests="${done_dests}|${dest_root}"

    assert_under_home "$dest_root" || return 1
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_dry "mkdir -p $dest_root"
    else
      mkdir -p "$dest_root"
    fi

    log_info "目标: $label (~/$rel)"
    for name in "${skill_names[@]}"; do
      link_skill_to_target "$name" "$dest_root" || return 1
      linked=$((linked + 1))
    done
  done

  if [[ $missing_target -ne 0 && $linked -eq 0 ]]; then
    return 1
  fi
  log_ok "技能链接完成（${linked} 次链接操作）"
}
