---
description: Harden mode - loop fresh critique→fix sub-agents until only minor issues remain.
allowed-tools: Task, Read, Bash, Grep, Glob, TodoWrite
---

You are the orchestrator for a hardening loop. You do NOT review or edit code
yourself — each pass runs in a **fresh sub-agent** so it starts with no prior
bias from earlier passes. This is not optional: reusing your own context, or
having the same sub-agent do pass 2 after pass 1, defeats the purpose of the
loop. Every single pass must be a brand-new sub-agent with zero memory of
prior passes.

## SCOPE (same selection as /critique)

Pick the diff to harden, first match wins:
- Unstaged changes exist → `git diff`
- Only staged changes → `git diff --staged`
- No pending changes → latest commit `git diff HEAD~1`
- User specified a commit/range in $ARGUMENTS → use that

Resolve the scope once, up front, and pass the SAME scope to every sub-agent.

## LOOP

Repeat until a pass reports only minor (LOW) issues, or nothing changed:

1. Spawn a **fresh** sub-agent (Task tool, subagent_type "general-purpose")
   with the scope and these instructions. Do not reuse a prior sub-agent,
   do not continue this conversation yourself — a brand new Task call, every
   pass, with no shared memory of previous passes:

   > Critically inspect the code changes in <SCOPE>. Classify each issue
   > HIGH / MEDIUM / LOW using the /critique focus areas (goal achievement,
   > error handling, logic, security, code quality, missing pieces).
   > FIX every HIGH and MEDIUM issue directly in the code. Verify it still
   > compiles/builds. Do NOT touch LOW issues. Then report back as your final
   > message ONLY:
   >   VERDICT: CLEAN   (no HIGH/MEDIUM found this pass)
   >   VERDICT: FIXED   (fixed >=1 HIGH/MEDIUM)
   >   followed by a short bullet list of what was found + fixed, and any
   >   remaining LOW issues.

2. Read the sub-agent's verdict:
   - `VERDICT: FIXED` → loop again with a new fresh sub-agent (the fixes may
     have introduced or exposed new issues).
   - `VERDICT: CLEAN` → stop. Only minor issues remain.

3. Safety stop: if you have run 5 passes, stop and report — a still-dirty diff
   after 5 rounds means something needs a human.

## REPORT

After the loop, summarize to the user: number of passes, what each pass fixed,
and the remaining LOW issues from the final pass. Do not change git state
(no commits/staging) unless $ARGUMENTS says to.

$ARGUMENTS
