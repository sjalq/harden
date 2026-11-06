# harden

Two agent skills — `critique` and `harden` — for both **Claude Code** and
**Codex CLI**.

- `harden` — two strictly separate phases:
  1. **Discover.** Run N consecutive, read-only critique rounds (default 5),
     each in a brand-new sub-agent. Every round sees the same frozen scope
     plus a compact list of defects already found, so it hunts for *new*
     defects instead of repeating old ones. Findings are deduplicated by root
     cause into one canonical ledger with stable `C001`, `C002`... IDs.
  2. **Fix once.** One brand-new fixer gets the whole ledger, fixes every
     confirmed defect of any severity in one cohesive change, runs the
     build and tests, and reports each ID as `FIXED`, `REJECTED` or
     `BLOCKED`. No second fixer, no fix/re-review ping-pong.
- `critique` — the read-only discovery phase on its own.
  - Claude: the same multi-round ledger workflow `harden` uses (default 5
    rounds, `/critique 1` for a single round).
  - Codex: one severity-tagged review pass (HIGH/MEDIUM/LOW) over a diff.

**Every reviewer and the fixer run in a fresh sub-agent with no memory of
earlier rounds** (a new Claude `Agent`/`Task` call, or a new `codex exec`
subprocess, never a resumed or forked one). That isolation, plus the
read-only discovery phase, is what keeps the result honest.

## Install

```bash
git clone https://github.com/sjalq/harden.git
cd harden
./install.sh            # installs for whichever of Claude/Codex is present
```

Or just Claude / just Codex (these force the install even if the tool is
not detected):

```bash
./install.sh --claude
./install.sh --codex
```

Full manual steps, Codex's own native skill-installer path, and design
notes are in [`CLAUDE.md`](./CLAUDE.md) — that file is the source of truth
for install/usage on both tools; `AGENTS.md` just points to it (Codex reads
`AGENTS.md`, Claude reads `CLAUDE.md`, so both land in the same place).

**If you are an agent that's just been pointed at this repo:** clone it and
run `./install.sh`, then read `CLAUDE.md` for anything that needs more
detail. That's the whole install.

## Usage

Both `harden` forms and the Claude `critique` take an optional round count
followed by an optional scope: `[rounds] [scope]`.

```
/harden                    # Claude: 5 critique rounds over pending changes, then one fix pass
/harden 3                  # Claude: 3 critique rounds, then one fix pass
/harden 7 HEAD~2..HEAD     # Claude: 7 rounds over that range, then one fix pass
/critique                  # Claude: 5 read-only rounds, ledger only, no fixes
/critique 1 api/           # Claude: one read-only round scoped to api/
$harden                    # Codex: same two-phase harden
$critique HEAD~3           # Codex: one review pass over that range
```

With no scope, the whole pending worktree is reviewed (staged, unstaged and
relevant untracked files), or the latest commit when the tree is clean. If the
scope changes while critique rounds are running, the run stops with
`SCOPE_DRIFT` and never reverts anyone's work. Nothing is staged or committed
unless you ask for it.

## Why discovery and repair are separate

A loop that critiques its own fixes with the context that produced them just
confirms its own homework, and a critique-fix-critique loop tends to chase
the newest fix while older, deeper defects get lost. Collecting every defect
first, from several fresh reviewers that are told what is already known, gives
one complete picture. A single fixer then repairs the whole ledger coherently,
with evidence for every item it rejects.

## License

MIT — see [LICENSE](./LICENSE).
