#!/bin/bash

command_exists() {
  if command -v "$1" >/dev/null 2>&1; then
    # Command exists
    if [[ -n $2 ]]; then
      if [[ -n $4 ]]; then
        confirm "$4" "$2"
      else
        "$2"
      fi
    fi
  else
    # Command does not exist
    if [[ -n $3 ]]; then
      "$3"  # Execute the non-exists callback function
    fi
  fi
}

confirm() {
  local message=$1
  local callback=$2

  read "response?$message (yes/no): "
  case "$response" in
    [Yy][Ee][Ss])
      if [[ -n $callback ]]; then
        "$callback"  # Execute the callback function
      fi
      ;;
    *)
      echo "Confirmation declined"
      ;;
  esac
}

noop() {
}

