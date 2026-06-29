# shellcheck shell=sh disable=SC3044
# Sourced by bash and zsh startup files. Keep this POSIX-friendly; shell-specific
# history options are guarded below.

if [ -n "${DOTFILES_HISTORY_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
DOTFILES_HISTORY_LOADED=1
export DOTFILES_HISTORY_LOADED

if [ -n "${DOTFILES_HISTORY_DIR:-}" ]; then
  mkdir -p "$DOTFILES_HISTORY_DIR" 2>/dev/null || true
  _dotfiles_history_dir=$DOTFILES_HISTORY_DIR
else
  _dotfiles_history_dir=
  for _dotfiles_history_root in /persistent /workspaces "$HOME"; do
    if [ -d "$_dotfiles_history_root" ] && [ -w "$_dotfiles_history_root" ]; then
      _dotfiles_history_dir=$_dotfiles_history_root
      break
    fi
  done
fi

[ -n "$_dotfiles_history_dir" ] || _dotfiles_history_dir=$HOME

if [ -n "${BASH_VERSION:-}" ]; then
  export HISTFILE="$_dotfiles_history_dir/.bash_history"
  export HISTSIZE=100000
  export HISTFILESIZE=200000
  shopt -s histappend 2>/dev/null || true

  dotfiles_history_sync() {
    history -a
    history -n
  }

  case "${PROMPT_COMMAND:-}" in
    *dotfiles_history_sync*) ;;
    "") PROMPT_COMMAND=dotfiles_history_sync ;;
    *) PROMPT_COMMAND="dotfiles_history_sync; $PROMPT_COMMAND" ;;
  esac
elif [ -n "${ZSH_VERSION:-}" ]; then
  export HISTFILE="$_dotfiles_history_dir/.zsh_history"
  export HISTSIZE=100000
  export SAVEHIST=100000
  setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY 2>/dev/null || true
  setopt HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS 2>/dev/null || true
  setopt HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS 2>/dev/null || true
fi

if [ -n "${HISTFILE:-}" ]; then
  [ -e "$HISTFILE" ] || : > "$HISTFILE" 2>/dev/null || true
fi

unset _dotfiles_history_dir _dotfiles_history_root
