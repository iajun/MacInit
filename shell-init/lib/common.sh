#!/usr/bin/env bash
# Shared helpers for shell-init. Safe to source multiple times.

[[ -n "${_SHELL_INIT_COMMON_LOADED:-}" ]] && return 0
_SHELL_INIT_COMMON_LOADED=1

_SHELL_INIT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${SETUP_DIR:=$(cd "$_SHELL_INIT_LIB_DIR/.." && pwd)}"
: "${PACKAGES_DIR:=$SETUP_DIR/packages}"

# --- runtime flags (set by setup.sh) ---
: "${DRY_RUN:=0}"
: "${FORCE:=0}"
: "${ASSUME_YES:=0}"
: "${CONTINUE_ON_ERROR:=1}"
: "${BREW_MIRROR:=tuna}"
: "${FONT_KEYS:=}"
: "${SKILL_TARGETS:=}"
: "${BACKUP_ROOT:=}"
: "${NONINTERACTIVE:=1}"

# --- colors (TTY only) ---
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_CYAN=$'\033[36m'
  C_BLUE=$'\033[34m'
else
  C_RESET= C_BOLD= C_DIM= C_GREEN= C_YELLOW= C_RED= C_CYAN= C_BLUE=
fi

log_info()  { printf '%sℹ%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
log_ok()    { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_warn()  { printf '%s⚠%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err()   { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
log_step()  { printf '\n%s>>> %s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
log_dry()   { printf '%s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"; }

# Bash / zsh compatible prompt (sets named variable)
read_prompt() {
  local prompt="$1"
  local var_name="$2"
  if [[ -n "${BASH_VERSION:-}" ]]; then
    # shellcheck disable=SC2162
    read -r -p "$prompt" "$var_name"
  else
    eval "read \"?$prompt\" $var_name"
  fi
}

confirm_yn() {
  local message="$1"
  local default="${2:-n}"
  local hint response
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi
  if [[ "$default" =~ ^[Yy]$ ]]; then
    hint="Y/n"
  else
    hint="y/N"
  fi
  read_prompt "$message ($hint): " response
  response="${response:-$default}"
  [[ "$response" =~ ^[Yy]$ ]]
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_err "需要命令: $cmd"
    return 1
  fi
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

host_arch() {
  local m
  m="$(uname -m)"
  case "$m" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64)  echo "x86_64" ;;
    *)             echo "$m" ;;
  esac
}

# Ensure brew is on PATH (Apple Silicon / Intel)
ensure_brew_path() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    # shellcheck disable=SC1091
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    # shellcheck disable=SC1091
    eval "$(/usr/local/bin/brew shellenv)"
  else
    return 1
  fi
}

# Refuse paths that escape $HOME (symlink-aware via realpath when available)
assert_under_home() {
  local target="$1"
  local home_real target_real
  if command -v realpath >/dev/null 2>&1; then
    home_real="$(realpath "$HOME")"
    if [[ "${DRY_RUN:-0}" != "1" ]]; then
      mkdir -p "$(dirname "$target")" 2>/dev/null || true
    fi
    if [[ -e "$target" ]]; then
      target_real="$(realpath "$target")"
    elif [[ -d "$(dirname "$target")" ]]; then
      target_real="$(realpath "$(dirname "$target")")/$(basename "$target")"
    else
      # Parent may not exist yet (esp. dry-run); fall back to lexical HOME check
      target_real="$target"
    fi
  else
    home_real="$HOME"
    target_real="$target"
  fi
  # Lexical fallback when path not yet created
  case "$target_real" in
    "$home_real"|"$home_real"/*|"$HOME"|"$HOME"/*) return 0 ;;
    *)
      log_err "拒绝写入 $HOME 以外的路径: $target"
      return 1
      ;;
  esac
}

# Unified action runner: respects DRY_RUN
run_action() {
  local desc="$1"
  shift
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_dry "$desc"
    if [[ $# -gt 0 ]]; then
      log_dry "  → $*"
    fi
    return 0
  fi
  if [[ $# -eq 0 ]]; then
    log_info "$desc"
    return 0
  fi
  log_info "$desc"
  "$@"
}

run_step_safe() {
  local name="$1"
  shift
  log_step "$name"
  set +e
  "$@"
  local code=$?
  set -e
  if [[ $code -eq 0 ]]; then
    log_ok "$name 完成"
    return 0
  fi
  log_err "$name 失败 (exit $code)"
  return "$code"
}

resolve_brewfile() {
  local file="${1:-$PACKAGES_DIR/Brewfile}"
  if [[ ! -f "$file" ]]; then
    log_err "Brewfile 不存在: $file"
    return 1
  fi
  printf '%s\n' "$file"
}

# Download helper with basic HTTPS + fail-on-error (no pipe-to-shell)
fetch_to_file() {
  local url="$1"
  local dest="$2"
  require_cmd curl || return 1
  case "$url" in
    https://*) ;;
    *)
      log_err "仅允许 https URL: $url"
      return 1
      ;;
  esac
  curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout 30 --max-time 300 \
    -o "$dest" "$url"
}

# Temp dir with EXIT cleanup (call once; reuses existing)
make_temp_dir() {
  if [[ -z "${_SHELL_INIT_TMPDIR:-}" ]]; then
    _SHELL_INIT_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/shell-init.XXXXXX")"
    # shellcheck disable=SC2064
    trap '[[ -n "${_SHELL_INIT_TMPDIR:-}" ]] && rm -rf "$_SHELL_INIT_TMPDIR"' EXIT INT TERM
  fi
  printf '%s\n' "$_SHELL_INIT_TMPDIR"
}

require_macos() {
  if ! is_macos; then
    log_err "当前脚本仅支持 macOS"
    return 1
  fi
}
