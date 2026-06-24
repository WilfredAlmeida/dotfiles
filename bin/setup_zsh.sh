#!/usr/bin/env bash
set -euo pipefail

ASSUME_YES=0
CHANGE_SHELL=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -y|--yes)
      ASSUME_YES=1
      ;;
    --change-shell)
      CHANGE_SHELL=1
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: setup_zsh.sh [--yes] [--change-shell]

Installs zsh, Oh My Zsh, and the configured third-party plugins. This script
uses the network and package managers; shell startup itself does not.

Environment refs:
  OH_MY_ZSH_REF                  default: master
  ZSH_SYNTAX_HIGHLIGHTING_REF    default: 0.8.0
USAGE
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

confirm() {
  if [ "$ASSUME_YES" -eq 1 ]; then
    return 0
  fi

  local reply
  read -r -p "$1 [y/N] " reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) return 1 ;;
  esac
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

install_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    return 0
  fi

  if ! confirm "Install zsh using the system package manager?"; then
    printf 'zsh is required; aborting\n' >&2
    exit 1
  fi

  if [[ "${OSTYPE:-}" == darwin* ]]; then
    require_command brew
    brew install zsh
  elif command -v apt-get >/dev/null 2>&1; then
    require_command sudo
    sudo apt-get update
    sudo apt-get install -y zsh
  else
    printf 'unsupported OS/package manager; install zsh manually\n' >&2
    exit 1
  fi
}

clone_ref() {
  local repo=$1
  local dest=$2
  local ref=$3

  if [ -d "$dest" ]; then
    printf '[exists] %s\n' "$dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  git clone --depth=1 --branch "$ref" "$repo" "$dest"
}

install_zsh
require_command git

OH_MY_ZSH_REF=${OH_MY_ZSH_REF:-master}
ZSH_SYNTAX_HIGHLIGHTING_REF=${ZSH_SYNTAX_HIGHLIGHTING_REF:-0.8.0}

ZSH_DIR=${ZSH:-"$HOME/.oh-my-zsh"}
ZSH_CUSTOM_DIR=${ZSH_CUSTOM:-"$ZSH_DIR/custom"}

clone_ref "https://github.com/ohmyzsh/ohmyzsh.git" "$ZSH_DIR" "$OH_MY_ZSH_REF"
clone_ref "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
  "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_REF"

if [ "$CHANGE_SHELL" -eq 1 ]; then
  zsh_path=$(command -v zsh)
  if [ "${SHELL:-}" != "$zsh_path" ]; then
    if confirm "Change default shell to $zsh_path?"; then
      chsh -s "$zsh_path"
    fi
  fi
fi

printf 'ZSH setup complete. Restart your terminal for changes to take effect.\n'
