# shellcheck shell=sh

if [ -n "${DOTFILES_CODEX_HOME:-}" ]; then
  CODEX_HOME=$DOTFILES_CODEX_HOME
elif [ -d /persistent ]; then
  CODEX_HOME=/persistent/.codex
else
  CODEX_HOME=$HOME/.codex
fi
export CODEX_HOME

mkdir -p "$CODEX_HOME" 2>/dev/null || true
