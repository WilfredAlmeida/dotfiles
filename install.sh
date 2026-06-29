#!/bin/sh
set -eu

script_dir() {
    script=$0
    case "$script" in
        */*) ;;
        *) script=$(command -v "$script") || return 1 ;;
    esac

    while [ -L "$script" ]; do
        dir=$(CDPATH='' cd "$(dirname "$script")" && pwd -P) || return 1
        link=$(readlink "$script") || return 1
        case "$link" in
            /*) script=$link ;;
            *) script=$dir/$link ;;
        esac
    done

    CDPATH='' cd "$(dirname "$script")" && pwd -P
}

ROOT=${DOTFILES_ROOT:-$(script_dir)}
DOTFILES_ROOT=$ROOT
DOTFILES_SKIP="${DOTFILES_SKIP:-} .bashrc .zshrc .gitconfig .ssh/config"
export DOTFILES_ROOT DOTFILES_SKIP

backup_file() {
    target=$1
    backup=$target.pre-dotfiles

    if [ ! -e "$backup" ]; then
        cp -p "$target" "$backup"
    fi
}

link_file() {
    rel=$1
    source=$2
    target=$HOME/$rel

    if [ -L "$target" ]; then
        current=$(readlink "$target") || return 1
        if [ "$current" = "$source" ]; then
            printf '[exists]  %s\n' "$rel"
            return 0
        fi

        printf '[collide] %s -> %s\n' "$rel" "$current" >&2
        return 1
    fi

    if [ -e "$target" ]; then
        return 2
    fi

    printf '[link]    %s\n' "$rel"
    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
}

source_from_existing() {
    rel=$1
    source=$2
    target=$HOME/$rel
    begin="# >>> dotfiles $rel >>>"
    end="# <<< dotfiles $rel <<<"

    if link_file "$rel" "$source"; then
        return 0
    else
        status=$?
    fi

    if [ "$status" -ne 2 ]; then
        return 1
    fi

    if [ -d "$target" ]; then
        printf '[collide] %s\n' "$rel" >&2
        return 1
    fi

    if grep -F "$begin" "$target" >/dev/null 2>&1; then
        printf '[exists]  %s source block\n' "$rel"
        return 0
    fi

    backup_file "$target"
    printf '[merge]   %s source block\n' "$rel"
    {
        printf '\n%s\n' "$begin"
        printf 'if [ -r "%s" ]; then\n' "$source"
        printf '  . "%s"\n' "$source"
        printf 'fi\n'
        printf '%s\n' "$end"
    } >> "$target"
}

include_from_existing() {
    rel=$1
    source=$2
    target=$HOME/$rel

    if link_file "$rel" "$source"; then
        return 0
    else
        status=$?
    fi

    if [ "$status" -ne 2 ]; then
        return 1
    fi

    if [ -d "$target" ]; then
        printf '[collide] %s\n' "$rel" >&2
        return 1
    fi

    if grep -F "$source" "$target" >/dev/null 2>&1; then
        printf '[exists]  %s include\n' "$rel"
        return 0
    fi

    backup_file "$target"
    printf '[merge]   %s include\n' "$rel"
    {
        printf '\n[include]\n'
        printf '\tpath = %s\n' "$source"
    } >> "$target"
}

include_ssh_config() {
    rel=.ssh/config
    source=$ROOT/.ssh/config.symlink
    target=$HOME/$rel
    include='Include ~/.ssh/conf.d/*.config'

    mkdir -p "$HOME/.ssh/conf.d"

    if link_file "$rel" "$source"; then
        return 0
    else
        status=$?
    fi

    if [ "$status" -ne 2 ]; then
        return 1
    fi

    if [ -d "$target" ]; then
        printf '[collide] %s\n' "$rel" >&2
        return 1
    fi

    if grep -F 'conf.d/*.config' "$target" >/dev/null 2>&1; then
        printf '[exists]  %s include\n' "$rel"
        return 0
    fi

    backup_file "$target"
    printf '[merge]   %s include\n' "$rel"
    {
        printf '\n%s\n' "$include"
    } >> "$target"
}

fix_ssh_permissions() {
    mkdir -p "$HOME/.ssh/conf.d"
    chmod 700 "$HOME/.ssh" "$HOME/.ssh/conf.d" 2>/dev/null || true
    [ ! -e "$HOME/.ssh/config" ] || chmod 600 "$HOME/.ssh/config" 2>/dev/null || true

    if [ -d "$ROOT/.ssh" ]; then
        find "$ROOT/.ssh" -type d -exec chmod go-w {} +
        find "$ROOT/.ssh" -type f -exec chmod go-w {} +
    fi
}

"$ROOT/bin/dotfiles.symlink" install
source_from_existing .bashrc "$ROOT/.bashrc.symlink"
source_from_existing .zshrc "$ROOT/.zshrc.symlink"
include_from_existing .gitconfig "$ROOT/.gitconfig.symlink"
include_ssh_config
fix_ssh_permissions

printf 'Dotfiles installation complete.\n'
