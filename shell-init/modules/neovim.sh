#!/usr/bin/env bash
# Module: Neovim + LazyVim
# Without --force: sync overlay onto existing ~/.config/nvim
# With --force: full reinstall (starter + overlay), backup first
# After config sync: headless Lazy bootstrap so plugins actually install

[[ -n "${_SHELL_INIT_MOD_NEOVIM_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_NEOVIM_LOADED=1

nvim_release_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo "arm64" ;;
    *)             echo "x86_64" ;;
  esac
}

install_nvim() {
  if command -v brew >/dev/null 2>&1 || { declare -F ensure_brew_path >/dev/null 2>&1 && ensure_brew_path; }; then
    if brew list neovim >/dev/null 2>&1 && [[ "${FORCE:-0}" != "1" ]]; then
      log_ok "neovim 已通过 Homebrew 安装"
      return 0
    fi
    run_action "通过 Homebrew 安装 neovim" brew install neovim
    return
  fi

  local arch version tmp
  arch="$(nvim_release_arch)"
  version="nvim-macos-${arch}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "下载 Neovim stable ($version) → ~/.local"
    return 0
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/nvim-install.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  log_info "下载 Neovim stable ($version)..."
  curl -fsSL -o "$tmp/${version}.tar.gz" \
    "https://github.com/neovim/neovim/releases/download/stable/${version}.tar.gz"
  tar xzf "$tmp/${version}.tar.gz" -C "$tmp"

  local prefix="${HOME}/.local"
  mkdir -p "$prefix/bin" "$prefix/share"
  rm -rf "$prefix/share/nvim"
  mv "$tmp/$version" "$prefix/share/nvim"
  ln -sfn "$prefix/share/nvim/bin/nvim" "$prefix/bin/nvim"
  ln -sfn "$prefix/share/nvim/bin/nvim" "$prefix/bin/v"
  log_ok "Neovim 已安装到 $prefix"
}

ensure_nvim() {
  if command -v nvim >/dev/null 2>&1 && [[ "${FORCE:-0}" != "1" ]]; then
    log_ok "Neovim 已安装 ($(command -v nvim))"
    return 0
  fi
  install_nvim
}

_copy_lazyvim_project_files() {
  local pkg="${1:-$PACKAGES_DIR/neovim}"

  if [[ -d "$pkg/lua" ]]; then
    sync_config_dir "$pkg/lua" ~/.config/nvim/lua
  else
    log_warn "找不到项目 lua 配置: $pkg/lua"
  fi

  [[ -f "$pkg/init.lua" ]] && sync_config_file "$pkg/init.lua" ~/.config/nvim/init.lua
  [[ -f "$pkg/stylua.toml" ]] && sync_config_file "$pkg/stylua.toml" ~/.config/nvim/stylua.toml
  [[ -f "$pkg/lazyvim.json" ]] && sync_config_file "$pkg/lazyvim.json" ~/.config/nvim/lazyvim.json
  [[ -f "$pkg/.neoconf.json" ]] && sync_config_file "$pkg/.neoconf.json" ~/.config/nvim/.neoconf.json
}

# Remove leftover lazy.nvim lock/clone markers and broken plugin trees
_cleanup_broken_lazy_plugins() {
  local lazy_root="${HOME}/.local/share/nvim/lazy"
  local p name
  [[ -d "$lazy_root" ]] || return 0

  find "$lazy_root" -maxdepth 1 -name '*.cloning' -type f -delete 2>/dev/null || true

  # Broken bootstrap: directory exists but lua/lazy/init.lua missing
  if [[ -e "$lazy_root/lazy.nvim" && ! -f "$lazy_root/lazy.nvim/lua/lazy/init.lua" ]]; then
    log_warn "检测到残缺 lazy.nvim，清理后重装"
    rm -rf "$lazy_root/lazy.nvim"
  fi

  # Drop plugin dirs with no usable git HEAD (causes lazy lock assert)
  for p in "$lazy_root"/*; do
    [[ -d "$p" ]] || continue
    name="$(basename "$p")"
    [[ "$name" == "lazy.nvim" ]] && continue
    if [[ -d "$p/.git" ]] && ! git -C "$p" rev-parse HEAD >/dev/null 2>&1; then
      log_warn "清理无 commit 的插件目录: $name"
      rm -rf "$p"
    fi
  done
}

# Clone LazyVim starter via SSH-friendly URL (honors git insteadOf / proxy)
_clone_lazyvim_starter() {
  local dest="$1"
  if git clone --depth=1 git@github.com:LazyVim/starter.git "$dest" 2>/dev/null; then
    return 0
  fi
  git clone --depth=1 https://github.com/LazyVim/starter.git "$dest"
}

install_lazynvim_full() {
  local pkg="$PACKAGES_DIR/neovim"

  assert_under_home ~/.config/nvim || return 1

  if [[ -e ~/.config/nvim || -L ~/.config/nvim ]]; then
    backup_path ~/.config/nvim
  fi
  # Also backup data/cache dirs that will be wiped
  [[ -d ~/.local/share/nvim ]] && backup_path ~/.local/share/nvim
  [[ -d ~/.local/state/nvim ]] && backup_path ~/.local/state/nvim
  [[ -d ~/.cache/nvim ]] && backup_path ~/.cache/nvim

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "全量安装 LazyVim starter + overlay"
    log_dry "清理 ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim"
    log_dry "git clone LazyVim/starter → ~/.config/nvim"
    log_dry "应用 packages/neovim overlay"
    log_dry "headless: nvim Lazy! sync"
    return 0
  fi

  log_info "开始全量安装 LazyVim..."
  rm -rf ~/.config/nvim
  rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
  mkdir -p ~/.config

  if ! _clone_lazyvim_starter ~/.config/nvim; then
    log_err "克隆 LazyVim starter 失败（检查 GitHub SSH/网络）"
    return 1
  fi
  rm -rf ~/.config/nvim/.git
  log_ok "已克隆 LazyVim starter"

  if [[ -d ~/.config/nvim/lua ]]; then
    rm -rf ~/.config/nvim/lua
  fi

  _copy_lazyvim_project_files "$pkg"
  bootstrap_lazyvim_plugins || return 1
  log_ok "LazyVim 全量安装完成"
}

sync_lazynvim() {
  local pkg="$PACKAGES_DIR/neovim"
  if [[ ! -d ~/.config/nvim ]]; then
    log_warn "~/.config/nvim 不存在；改为全量安装"
    install_lazynvim_full
    return
  fi
  _copy_lazyvim_project_files "$pkg"
  log_ok "LazyVim 配置已同步"
  bootstrap_lazyvim_plugins || return 1
}

# Install / repair plugins after config is in place
bootstrap_lazyvim_plugins() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "nvim --headless '+Lazy! sync' +qa"
    return 0
  fi

  if ! command -v nvim >/dev/null 2>&1; then
    log_err "未找到 nvim，无法安装 LazyVim 插件"
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    log_err "未找到 git，无法安装 LazyVim 插件"
    return 1
  fi

  _cleanup_broken_lazy_plugins

  local lazy_init="${HOME}/.local/share/nvim/lazy/LazyVim/lua/lazyvim/init.lua"
  if [[ -f "$lazy_init" && "${FORCE:-0}" != "1" ]]; then
    log_ok "LazyVim 插件已存在，跳过同步（需要重装请加 --force）"
    return 0
  fi

  log_info "同步 Lazy 插件（首次可能较慢，需可访问 GitHub）..."
  # Headless open triggers install_missing; prefer install({wait=true}) over
  # `:Lazy! sync` which can assert on lockfile when a clone is mid-flight.
  if ! nvim --headless \
    "+lua require('lazy').install({ wait = true })" \
    +qa; then
    log_warn "Lazy install 过程中有错误，继续检查结果"
  fi

  # Clear clone lock markers left by interrupted installs
  _cleanup_broken_lazy_plugins

  if [[ -f "$lazy_init" && -f "${HOME}/.local/share/nvim/lazy/lazy.nvim/lua/lazy/init.lua" ]]; then
    log_ok "LazyVim 插件安装完成"
    return 0
  fi

  log_err "LazyVim 插件未安装完整"
  log_info "常见原因: GitHub 不可达 / HTTPS 被墙但未开代理 / SSH insteadOf 无密钥"
  log_info "可手动执行: nvim --headless '+Lazy! sync' +qa"
  log_info "或交互打开 nvim 等待插件安装完成"
  return 1
}

step_neovim_check() {
  if command -v nvim >/dev/null 2>&1; then
    echo "ok: nvim=$(command -v nvim)"
  else
    echo "missing: nvim"
  fi
  if [[ -f "$HOME/.config/nvim/init.lua" ]]; then
    echo "ok: ~/.config/nvim"
  else
    echo "missing: ~/.config/nvim"
  fi
  if [[ -f "$HOME/.local/share/nvim/lazy/LazyVim/lua/lazyvim/init.lua" ]]; then
    echo "ok: LazyVim plugins"
  else
    echo "missing: LazyVim plugins (~/.local/share/nvim/lazy)"
  fi
  if [[ -f "$HOME/.local/share/nvim/lazy/lazy.nvim/lua/lazy/init.lua" ]]; then
    echo "ok: lazy.nvim"
  else
    echo "missing: lazy.nvim (broken or incomplete bootstrap)"
  fi
  return 0
}

step_neovim_run() {
  ensure_nvim || return 1
  if [[ "${FORCE:-0}" == "1" ]]; then
    install_lazynvim_full
  else
    sync_lazynvim
  fi
}
