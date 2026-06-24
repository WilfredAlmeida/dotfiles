#!/usr/bin/env bash
set -euo pipefail

BLINK_URL=${BLINK_URL:-"https://raw.githubusercontent.com/rrgeorge/vim-blink/master/blink.vim"}
BLINK_PATH=${BLINK_PATH:-"$HOME/.vim/autoload/blink.vim"}

if ! command -v curl >/dev/null 2>&1; then
  printf 'missing required command: curl\n' >&2
  exit 1
fi

mkdir -p "$(dirname "$BLINK_PATH")"
curl -fL --proto '=https' --tlsv1.2 -o "$BLINK_PATH" --create-dirs "$BLINK_URL"

printf 'Installed blink.vim to %s\n' "$BLINK_PATH"
