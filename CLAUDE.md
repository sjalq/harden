# harden — install & usage instructions

This repo ships two agent skills, `harden` and `critique`, in both Claude
Code and Codex CLI formats. This file is the single source of truth for
installing and using them correctly. `AGENTS.md` in this repo just points
here — Codex reads `AGENTS.md` the way Claude Code reads `CLAUDE.md`, so
this doc has to work for both audiences.

## What these skills do

- **`harden`** runs two strictly separate phases:
  1. **Discover**: N consecutive, read-only critique rounds (default 5).
     Each round is a fresh reviewer that gets the same frozen scope, the
     intended goal, and a compact exclusion list of defects already found.
     Findings are deduplicated by root cause into one canonical ledger with
     stable `C###` IDs. All requested rounds run, even when a round finds
     nothing. If the scope changes mid-run, it stops with `SCOPE_DRIFT`.
  2. **Fix once**: exactly one fresh fixer validates every ledger item,
     fixes every confirmed defect regardless of severity, adds regression
     tests where useful, runs formatter/compiler/tests, and reports every ID
     as `FIXED`, `REJECTED` (with contrary evidence) or `BLOCKED`. No second
     fixer and no post-fix critique loop. An empty ledger means no fixer.
- **`critique`** is discovery only and never edits code.
  - Claude (`claude/commands/critique.md`): the multi-round ledger workflow
    above. `harden` loads it with the Skill tool and then runs the fix phase.
    Reviewers read the target repo's (and relevant submodules') `CLAUDE.md`
    and `AGENTS.md` first.
  - Codex (`codex/skills/critique/SKILL.md`): one HIGH/MEDIUM/LOW review
    pass. The Codex `harden` skill carries its own multi-round discovery
    phase, so it does not depend on this file.

## The rule that matters: every reviewer and the fixer is a FRESH agent

Each critique round and the fixer must start with **zero memory** of earlier
rounds, otherwise a reviewer rubber-stamps work it already saw. Both
implementations enforce this as a hard requirement:

- **Claude**: a brand-new `general-purpose` sub-agent (Agent/Task tool) per
  round, run in the foreground and awaited before the next round, then one
  more brand-new sub-agent for the fix. Never resumed or reused.
- **Codex**: a brand-new `codex exec` **subprocess** per round and for the
  fixer, never `codex exec resume`, `--last`, a session ID, or `codex fork`.
  A bare `codex exec` call is a fresh context by construction.

Reviewers are told they are READ ONLY. Under Codex the nested calls use
`--dangerously-bypass-approvals-and-sandbox`, because nested macOS Seatbelt
sandboxes fail every shell command; the read-only instruction in the prompt
is then load-bearing, so keep it when editing the skill. The orchestrator
also checks that no reviewer changed any files.

If you're editing either skill file, do not "simplify" this into an in-line
loop that reasons about round 2 while still holding context from round 1, and
do not merge discovery and repair back into one loop. That silently breaks
the tool.

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

Install both files: `/harden` loads `critique` for its discovery phase.
No restart needed — new commands are picked up on the next Claude Code
session. `/harden` is user-invoked only (`disable-model-invocation: true`),
so the model will not start a hardening run on its own.

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
rm -rf ~/.codex/skills/harden ~/.codex/skills/critique
cp -R codex/skills/harden   ~/.codex/skills/harden
cp -R codex/skills/critique ~/.codex/skills/critique
```

Restart Codex (or start a new session) to pick up new skills. Requires
`codex` on `PATH` and already logged in (`codex login`) — the nested
`codex exec` calls reuse that same auth automatically.

To check that nested `codex exec` works on your machine, run
`codex/skills/harden/scripts/smoke-fresh-exec.sh` from inside a git repo.

## Installing on both at once

```bash
git clone https://github.com/sjalq/harden.git
cd harden
./install.sh
```

Detects whichever of Claude Code / Codex CLI is present (checks for the
binary on `PATH`, falls back to checking for `~/.claude` / `~/.codex`) and
installs into each. Passing `--claude` or `--codex` forces that install.
Safe to re-run.

## Usage

```
/harden                    # Claude: 5 read-only rounds over pending changes, then one fix pass
/harden 3                  # Claude: 3 rounds, then one fix pass
/harden 7 HEAD~2..HEAD     # Claude: 7 rounds over a range, then one fix pass
/critique 1 api/           # Claude: one read-only round scoped to api/, no fixes
$harden 3                  # Codex: same two-phase harden
$critique HEAD~3           # Codex: one review pass over a range
```

Arguments are `[rounds] [scope]`: a leading positive integer is the round
count, the rest is the scope. With no scope, the whole pending worktree is
reviewed (`git diff HEAD` plus relevant untracked files), or the latest
commit when the tree is clean. Nothing is staged or committed unless the
arguments explicitly ask for it.

## Repo layout

```
claude/commands/harden.md     Claude Code slash command (discover, then fix once)
claude/commands/critique.md   Claude Code slash command (multi-round discovery)
codex/skills/harden/          Codex skill (SKILL.md, agents/openai.yaml, scripts/smoke-fresh-exec.sh)
codex/skills/critique/        Codex skill (SKILL.md, agents/openai.yaml, scripts/smoke-fresh-exec.sh)
install.sh                    installs either or both
```
