# shellcheck shell=sh

if [ -n "${DOTFILES_CLAUDE_HOME:-}" ]; then
  CLAUDE_CONFIG_DIR=$DOTFILES_CLAUDE_HOME
elif mkdir -p /persistent/.claude 2>/dev/null && [ -w /persistent/.claude ]; then
  CLAUDE_CONFIG_DIR=/persistent/.claude
else
  CLAUDE_CONFIG_DIR=$HOME/.claude
fi
export CLAUDE_CONFIG_DIR

mkdir -p "$CLAUDE_CONFIG_DIR" 2>/dev/null || true
