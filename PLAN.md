# Agents Dotfiles Plan — share instructions + skills across all LLMs

## Goal

Make one set of agent instructions and skills follow the user everywhere the
dotfiles are applied, for **all** LLM CLIs (Codex, Claude, and future ones),
while keeping the repo easy to manage.

Two layers:

1. **Repo layout (for management convenience).** A single universal
   instructions file plus per-model folders for anything model-specific.
2. **Applied layout (for the models, out of the box).** At install time the
   universal file is written under whatever filename each model reads natively
   — `AGENTS.md` for Codex, `CLAUDE.md` for Claude — so no model needs extra
   configuration to pick it up.

## Repo layout change

Rename `codex/` to a shared `agents/` tree:

```
agents/
  AGENTS.md        # universal instructions — applies to ALL models
  codex/           # Codex-only overrides (model-specific); empty for now
  claude/          # Claude-only overrides (model-specific); empty for now
```

- Move `codex/AGENTS.md` -> `agents/AGENTS.md` (content unchanged).
- Create `agents/codex/` and `agents/claude/`, each with a `.gitkeep` so the
  empty dirs are tracked.
- Remove the now-empty `codex/` directory.

The per-model dirs are where the user drops model-specific files later. The
installer copies their contents verbatim into that model's home, overlaying
(overwriting) the universal file when names collide.

## Applied layout (what install.sh writes)

| Model  | Home dir (with persistence) | Universal file written as | Skills dir |
|--------|-----------------------------|---------------------------|------------|
| Codex  | `$CODEX_HOME` (`/persistent/.codex` if usable, else `$HOME/.codex`) | `AGENTS.md` | `$CODEX_HOME/skills/` |
| Claude | `$CLAUDE_HOME` (`/persistent/.claude` if usable, else `$HOME/.claude`) | `CLAUDE.md` | `$CLAUDE_HOME/skills/` |

Both reuse the same `/persistent`-then-`$HOME` writability fallback already
used for Codex (create + `-w` test before choosing `/persistent`).

For each model the installer:

1. Copies `agents/AGENTS.md` to the model's native instructions filename.
2. Overlays any files in `agents/<model>/` into the model's home (overwrite-wins).
3. Clones/updates `rust-skills` into `<home>/skills/rust-skills`
   (clone if missing, `git pull --ff-only` if present; network failures are
   non-fatal warnings — unchanged behavior).

Codex additionally keeps its existing `config.toml` step
(`sandbox_mode = "workspace-write"`, `approval_policy = "on-request"`). Claude
gets **no** auto-generated `settings.json` — its permission/config schema is
different, and the user didn't ask for it. Model-specific Claude settings can
live in `agents/claude/settings.json` and will be overlaid by step 2.

## File-by-file changes

### `agents/` (new tree)
- `git mv`/move `codex/AGENTS.md` -> `agents/AGENTS.md`.
- Add `agents/codex/.gitkeep`, `agents/claude/.gitkeep`.

### `shell/claude.sh` (new — mirrors `shell/codex.sh`)
```sh
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
```
(`CLAUDE_CONFIG_DIR` is the documented env var Claude Code reads to relocate
its config dir, so this works out of the box.)

### `install.sh`
- Point the Codex copy at the new path: `$ROOT/agents/AGENTS.md`.
- Add `claude_home_path()` mirroring `codex_home_path()` (for
  `/persistent/.claude` / `$HOME/.claude`, honoring `DOTFILES_CLAUDE_HOME`).
- Extract two shared helpers to avoid duplication:
  - `clone_or_update_skills <dest> <git-url> <label>` — the rust-skills
    clone/update logic, currently inline in `install_codex`.
  - `overlay_agent_dir <src-dir> <dest-dir>` — copy `agents/<model>/` contents
    into the model home if the dir is non-empty.
- Refactor `install_codex()` to use the new path + shared helpers.
- Add `install_claude()`: resolve `$CLAUDE_HOME`, `mkdir -p
  "$CLAUDE_HOME/skills"`, copy `agents/AGENTS.md` -> `$CLAUDE_HOME/CLAUDE.md`,
  overlay `agents/claude/`, clone/update rust-skills.
- In the run sequence: add `source_at_top .bashrc/.zshrc shell/claude.sh claude`
  (both files) and call `install_claude` alongside `install_codex`.

### `bin/doctor`
- Add `shell/claude.sh` syntax check (next to the `shell/codex.sh` one).
- Rename/repoint the "Codex agents template" check to verify
  `agents/AGENTS.md` exists.

### `README.md`
- Replace the Codex-only section with an "Agent instructions & skills" section
  describing the `agents/` tree, the universal-file-to-native-filename mapping,
  the per-model override dirs, and Claude's `CLAUDE_CONFIG_DIR` persistence.

## Open design choices (defaults chosen, flag if you disagree)

- **Overlay = overwrite-wins.** A file in `agents/claude/CLAUDE.md` replaces the
  universal one rather than appending. Append-merge is more work; not building
  it unless you want it.
- **Claude persistence via `CLAUDE_CONFIG_DIR`** to match Codex. If you'd rather
  keep Claude strictly at `~/.claude`, drop `shell/claude.sh` and just write to
  `$HOME/.claude`.
- **rust-skills cloned into Claude too.** Codex and Claude skill formats differ,
  so the same repo may not be fully Claude-compatible — but applying it matches
  your "skills for Claude as well" request. Easy to make Codex-only if it isn't.

## Verification (run after changes; no git actions)

- `sh -n install.sh`
- `sh -n shell/codex.sh`
- `sh -n shell/claude.sh`
- `sh -n shell/history.sh`
- `bash -n .bashrc.symlink`
- `zsh -n .zshrc.symlink`
- `git diff --check`
- `bin/doctor`
- Isolated install into a temp `HOME` with `DOTFILES_CODEX_HOME` /
  `DOTFILES_CLAUDE_HOME` set, asserting:
  - `$CODEX_HOME/AGENTS.md` and `$CLAUDE_HOME/CLAUDE.md` both exist and match
    `agents/AGENTS.md`.
  - idempotent on a second run.

## Out of scope / not doing

- No git commits or pushes — user will review and commit.
- No Claude `settings.json` generation.
- No append-merge of universal + model-specific instructions.
