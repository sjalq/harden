# harden — install & usage instructions

This repo ships two agent skills, `harden` and `critique`, in both Claude
Code and Codex CLI formats. This file is the single source of truth for
installing and using them correctly. `AGENTS.md` in this repo just points
here — Codex reads `AGENTS.md` the way Claude Code reads `CLAUDE.md`, so
this doc has to work for both audiences.

## What these skills do

- **`critique`** — one review pass over a diff (unstaged → staged → last
  commit → user-specified range, first match wins). Classifies findings
  HIGH/MEDIUM/LOW. Does not edit anything.
- **`harden`** — loops `critique`-then-fix passes until a pass comes back
  clean (HIGH/MEDIUM issues found and fixed, only LOW issues remain, or a
  5-pass safety stop is hit).

## The one rule that matters: every loop pass is a FRESH sub-agent

`harden`'s loop only works if each pass starts with **zero memory** of
earlier passes — otherwise a pass rubber-stamps its own (or a sibling
pass's) prior work instead of reviewing it with fresh eyes. Both
implementations in this repo enforce that as a hard requirement, not a
suggestion:

- **Claude**: `claude/commands/harden.md` spawns a new `Task` tool call
  (`subagent_type: general-purpose`) for every pass. Never a resumed or
  reused agent.
- **Codex**: `codex/skills/harden/SKILL.md` shells out to a brand-new
  `codex exec ...` **subprocess** for every pass — never `codex exec
  resume`, never `codex fork`, never done in the orchestrating session's
  own context. A bare `codex exec` call is a fresh context by construction;
  that's the whole mechanism.

If you're editing either skill file, do not "simplify" this into an in-line
loop that reasons about pass 2 while still holding context from pass 1 —
that silently breaks the tool.

## Installing on Claude Code

Slash commands are just markdown files under `~/.claude/commands/` (or
`.claude/commands/` inside a specific project for a project-local install).

**Automatic:**
```bash
git clone https://github.com/sjalq/harden.git
cd harden
./install.sh --claude
```

**Manual:**
```bash
mkdir -p ~/.claude/commands
cp claude/commands/harden.md   ~/.claude/commands/harden.md
cp claude/commands/critique.md ~/.claude/commands/critique.md
```

No restart needed — new commands are picked up on the next Claude Code
session. Use as `/harden` and `/critique` (both accept an optional
commit/range/path argument, e.g. `/harden api/`).

## Installing on Codex CLI

Codex skills are directories under `$CODEX_HOME/skills/` (defaults to
`~/.codex/skills/`), each containing a `SKILL.md`.

**Automatic (this repo's script):**
```bash
git clone https://github.com/sjalq/harden.git
cd harden
./install.sh --codex
```

**Automatic (Codex's own skill-installer, no clone needed):** if you
already have Codex's built-in `skill-installer` skill (preinstalled by
default), just ask Codex to install from this repo, or run its script
directly:
```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo sjalq/harden --path codex/skills/harden --path codex/skills/critique
```

**Manual:**
```bash
mkdir -p ~/.codex/skills
cp -R codex/skills/harden   ~/.codex/skills/harden
cp -R codex/skills/critique ~/.codex/skills/critique
```

Restart Codex (or start a new session) to pick up new skills. Requires
`codex` on `PATH` and already logged in (`codex login`) — the `harden`
loop's nested `codex exec` calls reuse that same auth automatically.

## Installing on both at once

```bash
git clone https://github.com/sjalq/harden.git
cd harden
./install.sh
```

Detects whichever of Claude Code / Codex CLI is present (checks for the
binary on `PATH`, falls back to checking for `~/.claude` / `~/.codex`) and
installs into each. Safe to re-run.

## Usage

```
/harden                    # Claude: harden the current diff
/harden api/                # Claude: scoped to a subfolder
$harden                     # Codex short form, same semantics
$critique HEAD~3             # review a specific range, no fix loop
```

## Repo layout

```
claude/commands/harden.md     Claude Code slash command
claude/commands/critique.md   Claude Code slash command
codex/skills/harden/          Codex skill (SKILL.md + agents/openai.yaml)
codex/skills/critique/        Codex skill (SKILL.md + agents/openai.yaml)
install.sh                    installs either or both
```
