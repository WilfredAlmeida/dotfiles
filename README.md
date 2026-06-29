# dotfiles

Personal dotfiles managed with simple symlinks. Files ending in `.symlink`
are installed into `$HOME` with that suffix removed.

For example:

```text
.vimrc.symlink       -> ~/.vimrc
.ssh/config.symlink  -> ~/.ssh/config
bin/dotfiles.symlink -> ~/bin/dotfiles
```

## Install

Coder runs the top-level `install.sh` automatically when applying this repo as
workspace dotfiles. That script preserves existing Coder/devcontainer shell,
Git, and SSH setup by merging include/source blocks instead of replacing those
files directly.

Preview the links first:

```sh
bin/dotfiles.symlink --dry-run install
```

Install:

```sh
bin/dotfiles.symlink install
```

The installer resolves the repository from the script path. If needed, override
it explicitly:

```sh
DOTFILES_ROOT=/path/to/dotfiles bin/dotfiles.symlink install
```

Uninstall links created by the installer:

```sh
bin/dotfiles.symlink uninstall
```

By default uninstall leaves `~/bin/dotfiles` in place. Use `FULL=1` to remove
that link too.

## Setup Scripts

Shell startup files do not create SSH keys, start new agents, or download code.
Those operations are explicit:

```sh
bin/setup_ssh.sh
bin/setup_zsh.sh
bin/setup_vim.sh
```

`setup_zsh.sh` uses package managers and clones third-party repositories:

- `https://github.com/ohmyzsh/ohmyzsh.git`
- `https://github.com/zsh-users/zsh-syntax-highlighting.git`

Default plugin refs can be overridden with:

```sh
OH_MY_ZSH_REF=master
ZSH_SYNTAX_HIGHLIGHTING_REF=0.8.0
```

`setup_vim.sh` downloads `blink.vim` from:

```text
https://raw.githubusercontent.com/rrgeorge/vim-blink/master/blink.vim
```

## Security Notes

Do not commit private keys, tokens, host-specific SSH config, or generated
shell history. Local SSH include files can be named like this and ignored:

```text
.ssh/conf.d/work.local.config
```

OpenSSH rejects configs if `~/.ssh` or included config targets are writable by
other users. Run this after install if permissions drift:

```sh
bin/setup_ssh.sh --no-key
```

## Doctor

Run:

```sh
bin/doctor
```

It checks shell syntax, ShellCheck when available, temp-home installation,
SSH config loading, Vim config loading, and missing optional zsh plugins.
