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
     -s workspace-write \
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
   PROMPT
   )"

   PASS_RESULT="$(cat "$OUT")"
   echo "$PASS_RESULT"
   ```

   Use `-s workspace-write` so the subprocess can actually apply fixes.
   `-o "$OUT"` writes just the agent's final message to a file so you can
   read the verdict without wading through the subprocess's own tool-call
   transcript.

2. Read `$PASS_RESULT`:
   - Contains `VERDICT: FIXED` → increment `PASS_N`, go back to step 1 with a
     **new** `mktemp` output file and a **new** `codex exec` call (fixes may
     have introduced or exposed new issues — the next pass needs fresh eyes
     on the now-changed diff).
   - Contains `VERDICT: CLEAN` → stop. Only minor issues remain.
   - Contains neither (subprocess crashed, timed out, or ignored the format)
     → treat as a failed pass, report it, and stop rather than looping
     blindly.

3. Safety stop: if `PASS_N` reaches 5, stop and report — a still-dirty diff
   after 5 fresh independent passes means something needs a human, not
   another automated round.

## REPORT

After the loop, summarize to the user: number of passes, what each pass
fixed, and the remaining LOW issues from the final pass. Do not change git
state (no commits/staging) unless the user's arguments say to.

## Prerequisites

- `codex` CLI on `$PATH` and already authenticated (`codex login` once,
  system-wide) — nested `codex exec` calls inherit the same `$CODEX_HOME`
  and need no extra setup.
- Run from inside a git repository (or pass `-C` to point at one).
