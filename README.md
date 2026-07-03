# harden

Two agent skills — `critique` and `harden` — for both **Claude Code** and
**Codex CLI**.

- `critique` — one severity-tagged review pass (HIGH/MEDIUM/LOW) over a
  diff. Read-only, no loop.
- `harden` — loops fresh critique-then-fix passes until a pass comes back
  clean. **Every pass runs in a brand-new sub-agent with no memory of prior
  passes** — that's the entire mechanism that keeps the loop honest, and
  it's non-negotiable in both implementations (a new Claude `Task` call, or
  a new `codex exec` subprocess, per pass — never a resumed/reused one).

## Install

```bash
git clone https://github.com/sjalq/harden.git
cd harden
./install.sh            # installs for whichever of Claude/Codex is present
```

Or just Claude / just Codex:

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

```
/harden                # Claude: harden the current diff (unstaged → staged → last commit)
/harden api/            # scoped to a subfolder
/critique HEAD~3         # Claude: review a specific range, no fix loop
$harden                  # Codex: same, short form
$critique                # Codex: same, short form
```

## Why "fresh sub-agent per pass" matters

A hardening loop that critiques its own fixes with the same context that
produced them just confirms its own homework. Fresh eyes on every pass is
the entire value proposition — so both skill definitions spell this out as
a hard requirement, not a style preference, and show the exact command
(`Task` tool call / `codex exec` invocation) to use so an agent following
the instructions can't accidentally collapse the loop into one long,
self-biased session.

## License

MIT — see [LICENSE](./LICENSE).
