#!/usr/bin/env bash
set -euo pipefail

ASSUME_YES=0
EMPTY_PASSPHRASE=0
CREATE_KEY=1
KEY_PATH=${KEY_PATH:-"$HOME/.ssh/id_ed25519"}
KEY_COMMENT=${KEY_COMMENT:-"${USER:-user}@$(hostname 2>/dev/null || printf unknown)"}

usage() {
  cat <<'USAGE'
Usage: setup_ssh.sh [--yes] [--no-key] [--empty-passphrase]

Prepares ~/.ssh permissions and optionally creates an ed25519 key. By default
ssh-keygen prompts for a passphrase; use --empty-passphrase only when that is
an explicit security choice.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -y|--yes)
      ASSUME_YES=1
      ;;
    --no-key)
      CREATE_KEY=0
      ;;
    --empty-passphrase)
      EMPTY_PASSPHRASE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      usage >&2
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

script_dir() {
  local script=$0
  case "$script" in
    */*) ;;
    *) script=$(command -v "$script") ;;
  esac

  while [ -L "$script" ]; do
    local dir link
    dir=$(CDPATH='' cd "$(dirname "$script")" && pwd -P)
    link=$(readlink "$script")
    case "$link" in
      /*) script=$link ;;
      *) script=$dir/$link ;;
    esac
  done

  CDPATH='' cd "$(dirname "$script")" && pwd -P
}

default_root() {
  local dir
  dir=$(script_dir)
  CDPATH='' cd "$dir/.." && pwd -P
}

DOTFILES_ROOT=${DOTFILES_ROOT:-$(default_root)}

mkdir -p "$HOME/.ssh/conf.d"
chmod 700 "$HOME/.ssh" "$HOME/.ssh/conf.d"

if [ -d "$DOTFILES_ROOT/.ssh" ]; then
  find "$DOTFILES_ROOT/.ssh" -type d -exec chmod go-w {} +
  find "$DOTFILES_ROOT/.ssh" -type f -exec chmod go-w {} +
fi

if [ "$CREATE_KEY" -eq 1 ] && [ ! -e "$KEY_PATH" ]; then
  if confirm "Create SSH key at $KEY_PATH?"; then
    mkdir -p "$(dirname "$KEY_PATH")"
    if [ "$EMPTY_PASSPHRASE" -eq 1 ]; then
      ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$KEY_COMMENT" -N ""
    else
      ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$KEY_COMMENT"
    fi
  fi
fi

printf 'SSH setup complete.\n'
