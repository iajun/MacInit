#!/usr/bin/env bash
# Module: optional Nerd Fonts via Homebrew casks.
# Default FONT_KEYS empty — Meslo comes from Brewfile.

[[ -n "${_SHELL_INIT_MOD_FONTS_LOADED:-}" ]] && return 0
_SHELL_INIT_MOD_FONTS_LOADED=1

# key|cask|label
FONT_CATALOG=(
  "meslo|font-meslo-lg-nerd-font|Meslo LG Nerd Font (推荐，终端/Powerlevel10k)"
  "jetbrains|font-jetbrains-mono-nerd-font|JetBrains Mono Nerd Font"
  "fira|font-fira-code-nerd-font|Fira Code Nerd Font (连字)"
  "hack|font-hack-nerd-font|Hack Nerd Font"
  "cascadia|font-caskaydia-cove-nerd-font|Caskaydia Cove (Cascadia) Nerd Font"
  "sauce|font-sauce-code-pro-nerd-font|Sauce Code Pro (Source Code Pro) Nerd Font"
  "iosevka|font-iosevka-nerd-font|Iosevka Nerd Font"
  "inconsolata|font-inconsolata-nerd-font|Inconsolata Nerd Font"
  "roboto|font-roboto-mono-nerd-font|Roboto Mono Nerd Font"
  "ubuntu|font-ubuntu-mono-nerd-font|Ubuntu Mono Nerd Font"
  "anonymice|font-anonymice-nerd-font|Anonymous Pro Nerd Font"
  "victor|font-victor-mono-nerd-font|Victor Mono Nerd Font"
)

font_key()   { cut -d'|' -f1 <<<"$1"; }
font_cask()  { cut -d'|' -f2 <<<"$1"; }
font_label() { cut -d'|' -f3- <<<"$1"; }

list_fonts() {
  local row
  printf '%-12s  %-40s  %s\n' "KEY" "CASK" "LABEL"
  printf '%s\n' "------------------------------------------------------------------------------------------------"
  for row in "${FONT_CATALOG[@]}"; do
    printf '%-12s  %-40s  %s\n' "$(font_key "$row")" "$(font_cask "$row")" "$(font_label "$row")"
  done
}

find_font_row() {
  local key="$1" row
  key="$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')"
  for row in "${FONT_CATALOG[@]}"; do
    if [[ "$(font_key "$row")" == "$key" ]]; then
      printf '%s\n' "$row"
      return 0
    fi
  done
  return 1
}

is_cask_installed() {
  local cask="$1"
  brew list --cask "$cask" >/dev/null 2>&1
}

install_font_cask() {
  local cask="$1"
  local label="$2"
  ensure_brew_path || {
    log_err "需要 Homebrew。请先运行 brew 安装步骤。"
    return 1
  }
  if is_cask_installed "$cask" && [[ "${FORCE:-0}" != "1" ]]; then
    log_ok "已安装: $label ($cask)"
    return 0
  fi
  run_action "安装字体: $label ($cask)" brew install --cask "$cask"
}

install_keys() {
  local key row cask label missing=0
  for key in "$@"; do
    [[ -z "$key" ]] && continue
    if ! row="$(find_font_row "$key")"; then
      log_warn "未知字体 key: $key（见 README 或 modules/fonts.sh）"
      missing=1
      continue
    fi
    cask="$(font_cask "$row")"
    label="$(font_label "$row")"
    install_font_cask "$cask" "$label" || missing=1
  done
  return "$missing"
}

step_fonts_check() {
  local key row cask
  if [[ -z "${FONT_KEYS:-}" ]]; then
    echo "ok: no extra fonts requested (Meslo via Brewfile)"
    return 0
  fi
  ensure_brew_path || { echo "missing: brew"; return 1; }
  local -a keys=()
  IFS=',' read -r -a keys <<<"$FONT_KEYS"
  for key in "${keys[@]}"; do
    [[ -z "$key" ]] && continue
    if row="$(find_font_row "$key")"; then
      cask="$(font_cask "$row")"
      if is_cask_installed "$cask"; then
        echo "ok: $key ($cask)"
      else
        echo "missing: $key ($cask)"
      fi
    fi
  done
  return 0
}

step_fonts_run() {
  require_macos || return 1
  local -a keys=()
  if [[ -n "${FONT_KEYS:-}" ]]; then
    IFS=',' read -r -a keys <<<"$FONT_KEYS"
  fi
  if [[ ${#keys[@]} -eq 0 ]]; then
    log_info "未指定 --fonts=；跳过额外字体（Meslo 已在 Brewfile）"
    return 0
  fi
  install_keys "${keys[@]}"
}
