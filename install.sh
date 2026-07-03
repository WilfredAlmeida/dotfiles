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

source_at_top() {
    rel=$1
    source=$2
    label=$3
    target=$HOME/$rel
    begin="# >>> dotfiles $label >>>"
    end="# <<< dotfiles $label <<<"

    if [ -L "$target" ]; then
        current=$(readlink "$target") || return 1
        case "$current" in
            "$ROOT"/*)
                rm "$target"
                : > "$target"
                ;;
            *)
                printf '[collide] %s -> %s\n' "$rel" "$current" >&2
                return 1
                ;;
        esac
    fi

    if [ -d "$target" ]; then
        printf '[collide] %s\n' "$rel" >&2
        return 1
    fi

    mkdir -p "$(dirname "$target")"
    [ -e "$target" ] || : > "$target"
    backup_file "$target"

    tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles-rc.XXXXXX") || return 1
    {
        printf '%s\n' "$begin"
        printf 'if [ -r "%s" ]; then\n' "$source"
        printf '  . "%s"\n' "$source"
        printf 'fi\n'
        printf '%s\n\n' "$end"
        awk -v begin="$begin" -v end="$end" '
            $0 == begin { skip = 1; next }
            skip && $0 == end { skip = 0; next }
            !skip { print }
        ' "$target"
    } > "$tmp"

    cat "$tmp" > "$target"
    rm -f "$tmp"
    printf '[merge]   %s %s block\n' "$rel" "$label"
}


codex_home_path() {
    if [ -n "${DOTFILES_CODEX_HOME:-}" ]; then
        printf '%s\n' "$DOTFILES_CODEX_HOME"
    elif mkdir -p /persistent/.codex 2>/dev/null && [ -w /persistent/.codex ]; then
        printf '%s\n' /persistent/.codex
    else
        printf '%s\n' "$HOME/.codex"
    fi
}

claude_home_path() {
    if [ -n "${DOTFILES_CLAUDE_HOME:-}" ]; then
        printf '%s\n' "$DOTFILES_CLAUDE_HOME"
    elif mkdir -p /persistent/.claude 2>/dev/null && [ -w /persistent/.claude ]; then
        printf '%s\n' /persistent/.claude
    else
        printf '%s\n' "$HOME/.claude"
    fi
}

# Copy the contents of a per-model overrides dir (agents/<model>/) into the
# model home, overwriting the universal file when names collide. The .gitkeep
# placeholder is skipped, and an empty dir is a no-op.
overlay_agent_dir() {
    src=$1
    dest=$2

    [ -d "$src" ] || return 0

    found=0
    for entry in "$src"/* "$src"/.[!.]*; do
        [ -e "$entry" ] || continue
        case "$(basename "$entry")" in
            .gitkeep) continue ;;
        esac
        cp -R "$entry" "$dest/"
        found=1
    done

    [ "$found" -eq 1 ] && printf '[merge]   %s overrides\n' "$(basename "$src")"
    return 0
}

# Clone a skills repo if missing, fast-forward it if already present. Network
# and state problems are non-fatal warnings, never errors.
clone_or_update_skills() {
    dest=$1
    url=$2
    label=$3

    if ! command -v git >/dev/null 2>&1; then
        printf '[warn]    missing git; skipped %s\n' "$label" >&2
        return 0
    fi

    if [ -d "$dest/.git" ]; then
        if git -C "$dest" pull --ff-only >/dev/null 2>&1; then
            printf '[exists]  %s updated\n' "$label"
        else
            printf '[warn]    failed to update %s at %s\n' "$label" "$dest" >&2
        fi
    elif [ -e "$dest" ]; then
        printf '[warn]    %s path exists and is not a git repo: %s\n' "$label" "$dest" >&2
    else
        if git clone --depth=1 "$url" "$dest" >/dev/null 2>&1; then
            printf '[link]    %s\n' "$label"
        else
            printf '[warn]    failed to clone %s into %s\n' "$label" "$dest" >&2
        fi
    fi
}

write_codex_config() {
    config=$CODEX_HOME/config.toml
    tmp=$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX") || return 1

    if [ -e "$config" ]; then
        awk '
            BEGIN { inserted = 0; in_table = 0 }
            !inserted && /^[[:space:]]*\[/ {
                print "sandbox_mode = \"workspace-write\""
                print "approval_policy = \"on-request\""
                print ""
                inserted = 1
                in_table = 1
            }
            !in_table && /^[[:space:]]*(sandbox_mode|approval_policy)[[:space:]]*=/ { next }
            { print }
            END {
                if (!inserted) {
                    print "sandbox_mode = \"workspace-write\""
                    print "approval_policy = \"on-request\""
                }
            }
        ' "$config" > "$tmp"
    else
        {
            printf '%s\n' 'sandbox_mode = "workspace-write"'
            printf '%s\n' 'approval_policy = "on-request"'
        } > "$tmp"
    fi

    cat "$tmp" > "$config"
    rm -f "$tmp"
}

RUST_SKILLS_URL=https://github.com/WilfredAlmeida/rust-skills.git

install_codex() {
    CODEX_HOME=$(codex_home_path)
    export CODEX_HOME

    mkdir -p "$CODEX_HOME/skills"
    cp "$ROOT/agents/AGENTS.md" "$CODEX_HOME/AGENTS.md"
    overlay_agent_dir "$ROOT/agents/codex" "$CODEX_HOME"
    write_codex_config
    clone_or_update_skills "$CODEX_HOME/skills/rust-skills" "$RUST_SKILLS_URL" "Codex rust skills"
}

install_claude() {
    CLAUDE_HOME=$(claude_home_path)

    mkdir -p "$CLAUDE_HOME/skills"
    cp "$ROOT/agents/AGENTS.md" "$CLAUDE_HOME/CLAUDE.md"
    overlay_agent_dir "$ROOT/agents/claude" "$CLAUDE_HOME"
    clone_or_update_skills "$CLAUDE_HOME/skills/rust-skills" "$RUST_SKILLS_URL" "Claude rust skills"
}

install_git_hooks() {
    hooks_dir=$ROOT/git/hooks

    if [ ! -x "$hooks_dir/dispatch" ]; then
        chmod +x "$hooks_dir/dispatch" 2>/dev/null || true
    fi

    if ! command -v git >/dev/null 2>&1; then
        printf '[warn]    missing git; skipped global hooks path\n' >&2
        return 0
    fi

    git config --global core.hooksPath "$hooks_dir"
    printf '[merge]   git core.hooksPath -> %s\n' "$hooks_dir"
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
source_at_top .bashrc "$ROOT/shell/history.sh" history
source_at_top .zshrc "$ROOT/shell/history.sh" history
source_at_top .bashrc "$ROOT/shell/codex.sh" codex
source_at_top .zshrc "$ROOT/shell/codex.sh" codex
source_at_top .bashrc "$ROOT/shell/claude.sh" claude
source_at_top .zshrc "$ROOT/shell/claude.sh" claude
install_codex
install_claude
install_git_hooks
source_from_existing .bashrc "$ROOT/.bashrc.symlink"
source_from_existing .zshrc "$ROOT/.zshrc.symlink"
include_from_existing .gitconfig "$ROOT/.gitconfig.symlink"
include_ssh_config
fix_ssh_permissions

printf 'Dotfiles installation complete.\n'
