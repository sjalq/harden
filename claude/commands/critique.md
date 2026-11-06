---
description: Run consecutive fresh, read-only critique rounds and return one deduplicated defect ledger.
argument-hint: "[rounds] [scope]"
allowed-tools: Agent, Task, Read, Bash, Grep, Glob
---

# Multi-round critique

You are the ROOT ORCHESTRATOR for a read-only defect-discovery workflow.
Critique only. Do not edit, write, format, stage, commit, or fix code.

## Arguments

If an invoking workflow supplied `CRITIQUE_CALLER_ARGUMENTS`, use that text.
Otherwise use the text below:

<RAW_ARGUMENTS>
$ARGUMENTS
</RAW_ARGUMENTS>

Parse the arguments as follows:

- If the first whitespace-separated token is a positive integer, it is the
  number of critique rounds. The remaining text is the requested scope.
- Otherwise run 5 rounds and treat all argument text as the requested scope.
- `/critique 1` therefore runs one round. `/critique 7 HEAD~2..HEAD` runs seven
  rounds over that range.

Run exactly the requested number of rounds. Never stop early because a round
finds nothing.

## Resolve and freeze the scope

Resolve the review target once, before spawning reviewers:

1. A scope explicitly supplied in the arguments wins.
2. Otherwise, if staged, unstaged, or untracked changes exist, inspect the
   whole pending worktree: `git diff HEAD` plus every relevant untracked file.
3. Otherwise inspect the latest commit: `git diff HEAD~1..HEAD`.

Determine the intended goal and acceptance criteria from the user's request,
ticket context, commit message, and surrounding code. Give every reviewer the
same goal and scope.

Record a `BASELINE_ID` covering HEAD, the selected tracked diff, and the
contents of selected untracked files. Recheck it after every round. If it
changes, stop with `SCOPE_DRIFT`; do not revert anybody's work.

## Consecutive critique rounds

For each round, spawn a brand-new `general-purpose` sub-agent in blocking or
foreground mode and wait for it to finish before spawning the next one. Never
resume or reuse a reviewer.

Give every reviewer:

- the same frozen scope and intended goal;
- the complete diff plus whatever surrounding code, call sites, tests, or
  configuration it needs to inspect;
- the compact exclusion list accumulated from earlier rounds.

Do not assign reviewers narrow lenses or category quotas. Each reviewer must
perform a fresh, unrestricted, complete critique for any concrete defect,
including goal failure, missing behavior, logic or state errors, edge cases,
error handling, races, security, data loss, integration failures, performance,
resource handling, compatibility, and inadequate tests.

Include these exact rules in every reviewer prompt:

> READ ONLY. Do not edit, write, format, stage, commit, fix code, invoke skills,
> or spawn other agents. Before starting the critique, read the CLAUDE.md and
> AGENTS.md files of the repository under review and of each relevant
> submodule, and use them as guidance. Inspect the complete frozen change and relevant
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

After each round, deduplicate only semantic duplicates and assign stable IDs
`C001`, `C002`, and so on. Preserve the full details in a canonical ledger.
Pass the next reviewer only compact exclusions in this form:

```text
C001 | path:line | one-sentence defect identity
```

Do not treat a shared line number as duplication. The defect identity and root
cause determine duplication.

## Result

After all rounds, return:

- the frozen scope and `BASELINE_ID`;
- new-defect count for every round;
- the complete canonical defect ledger, including all severities;
- coverage gaps or blocked checks;
- confirmation that no code was changed by this workflow.

If this workflow was loaded by another active workflow marked
`CRITIQUE_CALLER: harden`, retain the canonical ledger and continue that caller
instead of ending the turn after the critique report.
