#!/usr/bin/env bash
# Module: Xcode CLT + Homebrew + CLI Brewfile (+ Alacritty.app from GitHub)
# GUI apps: modules/apps.sh → packages/Brewfile.apps

[[ -n "${_SHELL_INIT_MOD_BREW_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_BREW_LOADED=1

# --- Xcode Command Line Tools -------------------------------------------------

clt_path() {
  xcode-select -p 2>/dev/null || true
}

clt_installed() {
  local p
  p="$(clt_path)"
  [[ -n "$p" && -d "$p" ]] || return 1
  # Prefer a real compiler presence check over path alone
  if [[ -x "$p/usr/bin/clang" ]] || command -v clang >/dev/null 2>&1; then
    return 0
  fi
  # Path set but incomplete
  return 1
}

# Try non-interactive softwareupdate install of "Command Line Tools for Xcode"
install_clt_via_softwareupdate() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "softwareupdate: 查找并安装 Command Line Tools for Xcode"
    return 0
  fi

  require_cmd softwareupdate || return 1

  local marker="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  # Known Apple pattern: create marker so CLT appears in softwareupdate -l
  touch "$marker" 2>/dev/null || true

  log_info "通过 softwareupdate 查找 Command Line Tools..."
  local list label
  list="$(softwareupdate --list 2>&1 || true)"
  # Prefer newest matching label
  label="$(
    printf '%s\n' "$list" \
      | awk -F'*' '/\*.*Command Line Tools/{print $2}' \
      | sed -e 's/^ *Label: //' -e 's/^ *//' \
      | grep -i 'Command Line Tools' \
      | sort -V \
      | tail -n1
  )"
  # Fallback: Label: lines on following row (older macOS output)
  if [[ -z "$label" ]]; then
    label="$(
      printf '%s\n' "$list" \
        | grep -i 'Command Line Tools' \
        | sed -n 's/.*Label:[[:space:]]*//p' \
        | sort -V \
        | tail -n1
    )"
  fi

  if [[ -z "$label" ]]; then
    rm -f "$marker" 2>/dev/null || true
    log_warn "softwareupdate 未列出 Command Line Tools（可能已装、需登录，或目录不可用）"
    return 1
  fi

  log_info "安装: $label"
  if softwareupdate --install "$label" --agree-to-license; then
    rm -f "$marker" 2>/dev/null || true
    if clt_installed; then
      log_ok "Xcode CLI 已通过 softwareupdate 安装"
      return 0
    fi
  fi
  rm -f "$marker" 2>/dev/null || true
  return 1
}

install_xcode_cli() {
  if clt_installed; then
    log_ok "Xcode CLI 已就绪: $(clt_path)"
    return 0
  fi

  log_info "未检测到完整 Xcode Command Line Tools"

  # a) already handled above
  # b) softwareupdate (preferred automated path)
  if install_clt_via_softwareupdate; then
    return 0
  fi

  # c) GUI installer fallback
  run_action "触发 xcode-select --install（系统弹窗）" xcode-select --install || true
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    return 0
  fi

  log_warn "请在系统弹窗中完成安装。等待 CLT 就绪（最多约 10 分钟）..."
  log_info "若弹窗未出现或失败，可手动: 系统设置 → 软件更新，或见 README「Xcode CLT」"
  local i
  for ((i = 0; i < 120; i++)); do
    if clt_installed; then
      log_ok "Xcode CLI 已就绪: $(clt_path)"
      return 0
    fi
    sleep 5
  done
  log_err "Xcode CLI 仍未就绪。可选: Apple Developer 下载页手动安装（需 Apple ID，本脚本不自动登录）"
  log_err "  https://developer.apple.com/download/all/?q=command%20line%20tools"
  return 1
}

# --- Homebrew -----------------------------------------------------------------

install_homebrew() {
  apply_mirror_env "$BREW_MIRROR" || return 1

  local tmp installer
  tmp="$(make_temp_dir)"
  installer="$tmp/homebrew-install.sh"

  run_action "下载 Homebrew 官方安装脚本" \
    fetch_to_file "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "$installer" \
    || return 1

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "运行 Homebrew 安装脚本（mirror=$BREW_MIRROR）"
    return 0
  fi

  if ! grep -q 'HOMEBREW' "$installer"; then
    log_err "安装脚本内容异常，已中止"
    return 1
  fi

  log_info "运行 Homebrew 安装脚本..."
  NONINTERACTIVE="${NONINTERACTIVE:-1}" /bin/bash "$installer"
  ensure_brew_path || {
    log_err "Homebrew 安装后仍未找到 brew"
    return 1
  }
  log_ok "Homebrew 已安装"
}

ensure_homebrew() {
  if ensure_brew_path; then
    log_ok "Homebrew 已可用: $(command -v brew)"
    apply_mirror_env "$BREW_MIRROR" || true
    return 0
  fi
  log_info "未检测到 Homebrew，开始安装..."
  install_homebrew
}

brew_bundle_install() {
  local brewfile
  brewfile="$(resolve_brewfile)" || return 1

  ensure_brew_path || {
    log_err "brew 不可用"
    return 1
  }

  apply_mirror_env "$BREW_MIRROR" || return 1

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "brew bundle install --file=$brewfile  (CLI 工具)"
    return 0
  fi

  log_info "使用 Brewfile (CLI): $brewfile"
  if ! brew bundle install --file="$brewfile"; then
    log_err "brew bundle install 失败"
    return 1
  fi

  if ! brew bundle check --file="$brewfile"; then
    log_err "Brewfile 中仍有未安装项"
    return 1
  fi
  log_ok "brew bundle (CLI) 完成"
}

# Alacritty 官方 cask 因 Gatekeeper 被禁用，从 GitHub Release 安装。
install_alacritty_github() {
  if [[ -d "/Applications/Alacritty.app" && "${FORCE:-0}" != "1" ]]; then
    log_ok "Alacritty 已安装: /Applications/Alacritty.app"
    return 0
  fi
  if command -v alacritty >/dev/null 2>&1 && [[ "${FORCE:-0}" != "1" ]]; then
    log_ok "Alacritty 已在 PATH: $(command -v alacritty)"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "从 GitHub Release 安装 Alacritty.app → /Applications"
    return 0
  fi

  require_cmd curl || return 1
  require_cmd hdiutil || return 1

  local tmp api tag url dmg mount
  tmp="$(make_temp_dir)/alacritty-dmg"
  mkdir -p "$tmp"
  api="$tmp/release.json"

  log_info "获取 Alacritty 最新 Release..."
  fetch_to_file "https://api.github.com/repos/alacritty/alacritty/releases/latest" "$api" || return 1
  tag="$(sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' "$api" | head -1)"
  if [[ -z "$tag" ]]; then
    log_err "无法解析 Alacritty tag"
    return 1
  fi

  url="https://github.com/alacritty/alacritty/releases/download/${tag}/Alacritty-${tag}.dmg"
  dmg="$tmp/Alacritty-${tag}.dmg"
  log_info "下载 Alacritty ${tag}..."
  fetch_to_file "$url" "$dmg" || return 1

  log_info "挂载并安装到 /Applications..."
  mount="$(hdiutil attach "$dmg" -nobrowse -readonly 2>/dev/null | awk '/\/Volumes\// {print $NF; exit}')"
  if [[ -z "$mount" || ! -d "$mount/Alacritty.app" ]]; then
    log_err "无法挂载 Alacritty DMG"
    return 1
  fi

  rm -rf /Applications/Alacritty.app
  if ! cp -R "$mount/Alacritty.app" /Applications/; then
    hdiutil detach "$mount" >/dev/null 2>&1 || true
    log_err "复制 Alacritty.app 失败（可能需要权限）"
    return 1
  fi
  hdiutil detach "$mount" >/dev/null 2>&1 || true
  xattr -dr com.apple.quarantine /Applications/Alacritty.app 2>/dev/null || true

  log_ok "Alacritty ${tag} 已安装（GitHub，已移除 quarantine）"
}

step_brew_check() {
  if clt_installed; then
    echo "ok: Xcode CLI=$(clt_path)"
  else
    echo "missing: Xcode Command Line Tools"
  fi
  if ensure_brew_path 2>/dev/null; then
    echo "ok: brew=$(command -v brew)"
  else
    echo "missing: Homebrew"
    return 1
  fi
  if [[ -d /Applications/Alacritty.app ]] || command -v alacritty >/dev/null 2>&1; then
    echo "ok: Alacritty present"
  else
    echo "missing: Alacritty.app"
  fi
  return 0
}

step_brew_run() {
  require_macos || return 1
  apply_mirror_env "$BREW_MIRROR" || return 1
  persist_mirror_choice "$BREW_MIRROR" || true

  install_xcode_cli || return 1
  ensure_homebrew || return 1
  brew_bundle_install || return 1
  install_alacritty_github
}
