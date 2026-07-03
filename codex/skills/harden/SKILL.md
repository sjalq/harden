---
name: harden
description: Harden mode - loop fresh critique-then-fix sub-agents, each a brand-new `codex exec` subprocess, until only minor issues remain. Use when the user asks to harden a branch, do a review-and-fix pass, or stabilize a diff before shipping.
metadata:
  short-description: Loop fresh codex-exec sub-agents until clean
---

# Harden (Codex)

You are the **orchestrator** for a hardening loop. You do NOT review or edit
code yourself, and you do NOT reason your way through the critique in this
conversation. Every single pass MUST run in a **fresh, disposable `codex exec`
subprocess** — a brand-new OS process with its own brand-new Codex context
that has never seen this conversation or any prior pass.

## THIS IS NOT OPTIONAL — READ BEFORE DOING ANYTHING ELSE

The entire point of the loop is that each critique pass starts with **zero
bias** from earlier passes (including its own earlier fixes). This property
is destroyed if you:

- Do the review/fix yourself in this session instead of shelling out.
- Reuse a subprocess across passes.
- Run `codex exec resume` / `codex exec resume --last` / `codex fork` for a
  pass — those explicitly carry over prior context, which is the opposite of
  what a fresh pass needs.
- Batch multiple passes into one `codex exec` prompt ("do 3 rounds of review
  and fix" in a single call) — that runs inside one context, not fresh ones.

**Every pass = exactly one new `codex exec ...` invocation, no history, no
resume flag, full stop.** If you find yourself about to read a diff and form
an opinion on it inside this conversation, stop — spawn the subprocess
instead and let it do that work.

## SCOPE (same selection as the `critique` skill)

Resolve the scope **once**, up front, and reuse the same scope text for every
pass:

```bash
cd "$(git rev-parse --show-toplevel)"
if [ -n "$(git diff)" ]; then
  SCOPE_DESC="unstaged changes"; SCOPE_CMD="git diff"
elif [ -n "$(git diff --staged)" ]; then
  SCOPE_DESC="staged changes"; SCOPE_CMD="git diff --staged"
elif [ -n "$ARGUMENTS" ]; then
  SCOPE_DESC="user-specified range: $ARGUMENTS"; SCOPE_CMD="git diff $ARGUMENTS"
else
  SCOPE_DESC="latest commit"; SCOPE_CMD="git diff HEAD~1"
fi
```

If the user gave an explicit commit/range/path argument, that always wins.

## THE LOOP

Repeat until a pass reports `VERDICT: CLEAN`, or you hit the 5-pass safety
stop. Track `PASS_N` starting at 1.

1. Launch a fresh subprocess for this pass. Do not add `resume`, `--last`,
   or any session-id flag — a bare `codex exec` call is a brand-new context
   by construction:

   ```bash
   REPO_ROOT="$(git rev-parse --show-toplevel)"
   OUT="$(mktemp -t harden-pass-XXXX).msg"

   codex exec \
     --skip-git-repo-check \
     --dangerously-bypass-approvals-and-sandbox \
     -C "$REPO_ROOT" \
     -o "$OUT" \
     "$(cat <<PROMPT
   Critically inspect the code changes below ($SCOPE_DESC). Get the exact
   diff yourself first by running: $SCOPE_CMD

   Classify each issue HIGH / MEDIUM / LOW:
   - Goal Achievement: do the changes accomplish what they appear to be trying to do?
   - Error Handling: are errors handled robustly for this language/stack?
   - Logic Issues: bugs, race conditions, incorrect behavior?
   - Security Concerns: any vulnerabilities introduced?
   - Code Quality: proper logging, no unsafe unwraps/crashes, idiomatic style?
   - Missing Pieces: obvious gaps in the implementation?

   FIX every HIGH and MEDIUM issue directly in the code. Verify it still
   compiles/builds/tests pass using this repo's normal commands. Do NOT touch
   LOW issues.

   Your FINAL message must contain ONLY:
     VERDICT: CLEAN   (no HIGH/MEDIUM found this pass)
   or
     VERDICT: FIXED   (fixed >=1 HIGH/MEDIUM)
   followed by a short bullet list of what was found + fixed, and any
   remaining LOW issues.

   If you cannot run shell commands at all (sandbox/permission failure before
   you ever saw the diff), do NOT report VERDICT: CLEAN — that would be a
   lie. Instead your final message must be exactly: VERDICT: ERROR followed
   by what failed.
   PROMPT
   )"

   PASS_RESULT="$(cat "$OUT")"
   echo "$PASS_RESULT"
   ```

   `--dangerously-bypass-approvals-and-sandbox` on the *nested* call is
   required, not optional — see the Gotcha below for why. `-o "$OUT"` writes
   just the agent's final message to a file so you can read the verdict
   without wading through the subprocess's own tool-call transcript.

2. Read `$PASS_RESULT`, and don't take a `VERDICT:` line on faith — a
   subprocess that never actually ran a command can still emit the right
   words. Cross-check with your own `git diff --stat` / `git status
   --short` (you're allowed normal repo-inspection commands in the
   orchestrator — you just can't do the *critique itself* here):
   - Contains `VERDICT: FIXED` → confirm the worktree actually changed
     (`git status --short` shows modified files), then increment `PASS_N`
     and go back to step 1 with a **new** `mktemp` output file and a **new**
     `codex exec` call — fixes may have introduced or exposed new issues,
     so the next pass needs fresh eyes on the now-changed diff.
   - Contains `VERDICT: CLEAN` with no working-tree changes since the pass
     started → stop. Only minor issues remain.
   - Contains `VERDICT: CLEAN` but the pass's own transcript shows every
     shell command failing (sandbox/permission errors, no tool calls ran at
     all) → this is a **false clean**, not a real pass. Treat it the same as
     `VERDICT: ERROR` below, do not stop the loop believing the code is
     hardened.
   - Contains `VERDICT: ERROR`, or neither CLEAN nor FIXED (subprocess
     crashed, timed out, ignored the format) → check whether the failure
     text is a **connection-level** error (e.g. `stream disconnected before
     completion`, `error sending request for url`, DNS failures) rather
     than a real review problem. These are transient backend/network
     hiccups, not findings about the code. Retry the *same* pass (same
     `PASS_N`, fresh `mktemp` file, identical prompt) up to 2 extra times.
     If it still hasn't produced a real verdict after 3 total attempts, only
     then treat this pass as a genuine failure, report it, and stop rather
     than looping blindly.

3. Safety stop: if `PASS_N` reaches 5 real (non-retry) passes, stop and
   report — a still-dirty diff after 5 fresh independent passes means
   something needs a human, not another automated round.

## REPORT

After the loop, summarize to the user: number of passes, what each pass
fixed, and the remaining LOW issues from the final pass. Do not change git
state (no commits/staging) unless the user's arguments say to.

## Prerequisites

- `codex` CLI on `$PATH` and already authenticated (`codex login` once,
  system-wide) — nested `codex exec` calls inherit the same `$CODEX_HOME`
  and need no extra setup.
- Run from inside a git repository (or pass `-C` to point at one).

## Gotcha: nested `codex exec` must bypass its own sandbox

You (the orchestrator) are almost always already running inside a sandbox
yourself (e.g. launched with `-s workspace-write`, or as someone's
sub-agent). macOS Seatbelt sandboxes don't nest: a `codex exec` subprocess
that tries to apply its *own* `workspace-write`/`read-only` sandbox while
already running inside your sandbox fails every single shell command,
including `git diff`, with `sandbox_apply: Operation not permitted` — the
subprocess never sees the diff at all. Confirmed by hand on macOS: a
sandboxed `-s workspace-write` inner call fails this way 100% of the time
when nested; the same call with `--dangerously-bypass-approvals-and-sandbox`
instead succeeds. That flag's own `--help` text says it's "intended solely
for running in environments that are externally sandboxed" — which is
exactly this situation, since you're already constraining the whole process
tree. That's why the command template above uses it instead of `-s
workspace-write`, and why step 2 above treats a `VERDICT: CLEAN` with no
actual tool calls as untrustworthy rather than a real pass — a broken
subprocess can still hallucinate the right verdict text.

A second, independent failure mode with the same symptom (no verdict, no
file changes): if the orchestrating sandbox blocks outbound network for
child processes, the nested call fails with `stream disconnected before
completion: error sending request for url (.../responses)` instead.
`--dangerously-bypass-approvals-and-sandbox` fixes this too, since it
removes the sandbox (and its network restriction) entirely for that one
nested call — it does not touch how you, the orchestrator, are sandboxed.

## Known limitation: nested calls can be network-flaky

Separately from the sandboxing issue above, a `codex exec` subprocess
launched while *another* `codex` process (you, the orchestrator) is itself
mid-turn can intermittently fail to reach the backend — `stream
disconnected before completion` — even with the sandbox fix applied and
even when the identical command run standalone (not nested) succeeds
immediately. Observed directly during development of this skill: the same
critique-and-fix call succeeded in under 30s every time it was run
standalone, but failed 3 times in a row when nested inside a live
interactive `codex` TUI session, and once inside a `codex exec`-driven
orchestrator too (hung past 3 minutes with no output). This looks like a
concurrency/connection limit on running two codex sessions under the same
auth at once, not a problem with the prompt or the command shape. The
retry-up-to-3× logic in step 2 exists specifically to absorb this. If you
hit it constantly in your environment, that's a real, still-open rough edge
in nesting `codex exec` — not a sign the skill is misconfigured.
