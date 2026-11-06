---
name: harden
description: Run consecutive fresh, read-only code critiques, consolidate every actionable defect, then make one cohesive fix pass. Use when asked to harden a branch, review and fix a diff, or stabilize a feature before shipping.
metadata:
  short-description: Discover defects first, then fix once
---

# Harden (Codex)

You are the orchestrator. Discovery and repair are separate phases. Do not
review or edit code yourself. Every reviewer and the sole fixer must be a
brand-new `codex exec` OS process with no resumed, forked, or inherited Codex
conversation. Do not let a worker invoke this skill or spawn its own agents.

Accept an optional positive round count followed by an optional scope. Default
to 5 critique rounds. Resolve the scope and intended goal once. An explicit
range/path wins; otherwise inspect the whole pending worktree (tracked changes
and relevant untracked files), or the latest commit when clean. Do not silently
substitute `HEAD~1` for a feature spanning several commits: use the user's
description and repository history to resolve its boundary, or ask if material
ambiguity remains.

Record a baseline fingerprint covering HEAD, the selected tracked diff, and
the contents of selected untracked files. Recheck it after every critique
round. If it changes, stop with `SCOPE_DRIFT`; never revert someone else's
work. Give every reviewer the same frozen scope, goal, and acceptance criteria.

## Phase 1: read-only discovery

Run exactly the requested number of consecutive, fresh critique rounds, even
when a round finds nothing. Use one new `codex exec` invocation per round; do
not use `resume`, `--last`, or a session ID. Never edit, format, stage, commit,
or fix during discovery.

Each reviewer gets the complete frozen change, relevant surrounding code and
tests, and only a compact exclusion list from earlier rounds. Do not assign
narrow lenses or quotas. Require a full critique for concrete goal failures,
missing behavior, logic and state errors, edge cases, error handling, races,
security, data loss, integration, performance, resources, compatibility, and
inadequate tests. Include these rules verbatim in every reviewer prompt:

> READ ONLY. Do not edit, write, format, stage, commit, fix code, invoke skills,
> or spawn other agents. Inspect the complete frozen change and relevant
> surrounding code. Report only concrete, actionable defects with specific
> file:line evidence and a plausible failure scenario.
>
> KNOWN DEFECTS are exclusions. Do not repeat, paraphrase, split, or severity-
> inflate an excluded defect, and do not report another symptom of the same
> root cause. These entries exclude defects, not files or lines: a genuinely
> different defect at the same location is allowed. `NO_NEW_FINDINGS` is a
> successful result. Never invent novelty merely because this is a later pass.

Require this result shape:

```text
ROUND: <n>/<total>
VERDICT: NEW_FINDINGS | NO_NEW_FINDINGS | BLOCKED
NEW_FINDINGS:
- SEVERITY: HIGH | MEDIUM | LOW
  LOCATION: path:line
  IDENTITY: one sentence naming the defect
  FAILURE: concrete trigger and incorrect outcome
  EVIDENCE: code or test evidence
  RECOMMENDED_FIX: concise direction
COVERAGE: files, call sites, and tests actually inspected
GAPS: anything the reviewer could not verify
```

After each round, deduplicate by root cause, not line number, and assign
stable IDs `C001`, `C002`, etc. Preserve complete evidence in one canonical
ledger. Pass the next reviewer only compact exclusions like
`C001 | path:line | one-sentence defect identity`.

Use `codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox
-C <repo> -o <unique-result-file> <prompt>` for each fresh process. The nested
bypass is necessary when macOS Seatbelt cannot nest. In that case the explicit
read-only instruction is load-bearing. Verify each reviewer actually inspected
the diff and made no file changes; a claimed clean result without working shell
tools is not evidence. For transient connection failures, retry the same round
with a new process, at most twice. Otherwise stop and report the failure.

If any round is blocked, the baseline drifts, or the requested rounds cannot
finish, stop without fixing. If the canonical ledger is empty, report the
completed rounds and stop without spawning a fixer.

## Phase 2: one cohesive fix pass

Spawn exactly one brand-new `codex exec` fixer. Give it the frozen scope, goal,
acceptance criteria, project instructions, relevant test commands, and the
complete canonical ledger with stable IDs and evidence. Instruct it:

> This is the only fixing round. Do not spawn agents, invoke skills, or start
> another critique/fix loop. Validate every ledger item against the code. Fix
> every confirmed actionable defect, regardless of severity, in one cohesive
> implementation. Add meaningful regression tests where appropriate. Run the
> relevant formatter, compiler, targeted tests, and broader test suite. Repair
> failures caused by your changes within this same turn. Do not stage or commit
> unless the user's original request explicitly asked for it. Report every
> ledger ID as `FIXED`, `REJECTED`, or `BLOCKED`; give changed files and
> verification for fixes, concrete contrary evidence for rejections, and the
> unresolved requirement for blocked items.

Do not launch a second fixer or a post-fix critique loop. A failed or
incomplete fixer is reported as such, not called clean. Preserve unrelated
worktree changes and do not publish or deploy without authorization.

## Report

Report requested and completed critique rounds, new findings per round, the
canonical ledger, disposition of every ID, verification results, blocked items,
and final unstaged git state. Never call the result `CLEAN` solely because
tests pass; state the evidence and any remaining uncertainty.
