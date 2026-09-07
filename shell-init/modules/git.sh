#!/usr/bin/env bash
# Module: git config from packages/git/default.txt + identity UX

[[ -n "${_SHELL_INIT_MOD_GIT_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_GIT_LOADED=1

configure_git_identity() {
  local existing_name existing_email
  existing_name="$(git config --global --get user.name 2>/dev/null || true)"
  existing_email="$(git config --global --get user.email 2>/dev/null || true)"

  local name="${GIT_USER_NAME:-}"
  local email="${GIT_USER_EMAIL:-}"
  local want_change=0

  if [[ -n "$existing_name" && -n "$existing_email" ]]; then
    log_info "当前 Git 身份: $existing_name <$existing_email>"

    # Env provided: only apply if FORCE or user confirms (wizard)
    if [[ -n "$name" || -n "$email" ]]; then
      if [[ "${FORCE:-0}" == "1" ]]; then
        want_change=1
      elif [[ "${ASSUME_YES:-0}" == "1" ]]; then
        log_ok "保留已有身份（非交互且未 --force；忽略 GIT_USER_*）"
        return 0
      elif [[ -t 0 ]]; then
        if confirm_yn "用环境变量/输入覆盖已有 Git 身份?" "n"; then
          want_change=1
        else
          log_ok "保留已有身份"
          return 0
        fi
      else
        log_ok "保留已有身份（非 TTY；覆盖请 --force 或向导确认）"
        return 0
      fi
    else
      # No env: wizard may offer optional change; non-interactive skips
      if [[ "${ASSUME_YES:-0}" == "1" || "${DRY_RUN:-0}" == "1" ]]; then
        log_ok "保留已有身份"
        return 0
      fi
      if [[ -t 0 ]] && confirm_yn "修改 Git 用户信息?" "n"; then
        want_change=1
        name=""
        email=""
      else
        log_ok "保留已有身份"
        return 0
      fi
    fi
  else
    # Missing identity
    log_warn "Git user.name / user.email 未完整设置"
    if [[ -n "$name" && -n "$email" ]]; then
      want_change=1
    elif [[ "${ASSUME_YES:-0}" == "1" ]]; then
      log_warn "--yes 且未设置 GIT_USER_NAME / GIT_USER_EMAIL — 跳过身份配置"
      return 0
    elif [[ -t 0 ]]; then
      want_change=1
    else
      log_warn "非交互且缺少身份；设置 GIT_USER_NAME / GIT_USER_EMAIL 后重跑 --steps=git"
      return 0
    fi
  fi

  if [[ $want_change -ne 1 ]]; then
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "将配置 git user.name / user.email"
    return 0
  fi

  # Prompt for missing pieces when interactive
  if [[ -z "$name" ]]; then
    if [[ -t 0 ]]; then
      read_prompt "Git user.name [${existing_name}]: " name
      name="${name:-$existing_name}"
    fi
  fi
  if [[ -z "$email" ]]; then
    if [[ -t 0 ]]; then
      read_prompt "Git user.email [${existing_email}]: " email
      email="${email:-$existing_email}"
    fi
  fi

  if [[ -z "$name" || -z "$email" ]]; then
    log_warn "姓名或邮箱仍为空，未写入"
    return 0
  fi

  git config --global user.name "$name"
  git config --global user.email "$email"
  log_ok "Git 身份: $name <$email>"
}

step_git_check() {
  if ! command -v git >/dev/null 2>&1; then
    echo "missing: git"
    return 1
  fi
  echo "ok: git=$(command -v git)"
  local n e
  n="$(git config --global --get user.name 2>/dev/null || true)"
  e="$(git config --global --get user.email 2>/dev/null || true)"
  if [[ -n "$n" && -n "$e" ]]; then
    echo "ok: user=$n <$e>"
  else
    echo "warn: git user.name / user.email 未设置"
  fi
  return 0
}

step_git_run() {
  local defaults="$PACKAGES_DIR/git/default.txt"
  require_cmd git || return 1

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "应用 git defaults: $defaults"
    local n e
    n="$(git config --global --get user.name 2>/dev/null || true)"
    e="$(git config --global --get user.email 2>/dev/null || true)"
    if [[ -n "$n" && -n "$e" ]]; then
      log_dry "保留已有身份: $n <$e>（除非 --force / 向导确认）"
    else
      log_dry "身份缺失: 向导会提示；CLI 用 GIT_USER_NAME/EMAIL；--yes 则警告跳过"
    fi
    [[ -n "${GIT_USER_NAME:-}" ]] && log_dry "env GIT_USER_NAME=$GIT_USER_NAME"
    [[ -n "${GIT_USER_EMAIL:-}" ]] && log_dry "env GIT_USER_EMAIL=$GIT_USER_EMAIL"
  else
    if [[ -f "$defaults" ]]; then
      local _section="" line
      while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" || "$line" == \#* || "$line" == \;* ]] && continue
        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
          _section="${BASH_REMATCH[1]}"
          continue
        fi
        if [[ -n "$_section" && "$line" =~ ^([A-Za-z0-9_.-]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
          git config --global "${_section}.${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        fi
      done <"$defaults"
      log_ok "已应用 $defaults"
    fi

    if [[ "${GIT_SSH_PROXY:-0}" == "1" ]]; then
      git config --global url."ssh://git@github.com/".insteadOf "https://github.com/"
      log_ok "已设置 SSH insteadOf"
    fi

    if [[ "${GIT_HTTP_PROXY:-0}" == "1" ]]; then
      git config --global http.https://github.com.proxy "socks5://127.0.0.1:7890"
      log_ok "已设置 GitHub HTTP 代理"
    fi
  fi

  configure_git_identity
}
