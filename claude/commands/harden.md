---
description: Run multi-round read-only critique, then fix the consolidated defect ledger once.
argument-hint: "[rounds] [scope]"
disable-model-invocation: true
allowed-tools: Skill, Agent, Task, Read, Bash, Grep, Glob, TodoWrite
---

# Harden

You are the ROOT ORCHESTRATOR. Discovery and repair are separate phases. You
do not review or edit code yourself.

`/harden` accepts the same arguments as `/critique`: an optional positive round
count followed by an optional scope. The default is 5 rounds.

CRITIQUE_CALLER: harden

<CRITIQUE_CALLER_ARGUMENTS>
$ARGUMENTS
</CRITIQUE_CALLER_ARGUMENTS>

## Phase 1: discover defects

Load the `critique` skill exactly once with the Skill tool. Do not type a nested
`/critique` command and do not duplicate or replace its review procedure here.
Execute the loaded workflow using `CRITIQUE_CALLER_ARGUMENTS` above.

Wait until all requested consecutive, read-only rounds are complete and its
canonical defect ledger exists. Do not permit any code change during this
phase. If it reports `SCOPE_DRIFT` or cannot finish, stop without fixing.

If the canonical ledger is empty, report the critique rounds and stop without
spawning a fixer.

## Phase 2: fix once

Spawn exactly one brand-new `general-purpose` fixer in blocking or foreground
mode. Pass it:

- the same resolved scope, intended goal, and acceptance criteria;
- the complete canonical ledger with stable `C###` IDs and evidence;
- the current project instructions and relevant test commands.

Give the fixer these instructions:

> This is the only fixing round. Do not spawn agents, invoke skills, or start
> another critique/fix loop. Validate every ledger item against the code. Fix
> every confirmed actionable defect, regardless of severity, in one cohesive
> implementation. Add or update meaningful regression tests where appropriate.
> Run the relevant formatter, compiler, targeted tests, and broader test suite.
> Repair failures caused by your changes within this same turn. Do not stage or
> commit unless the original user arguments explicitly requested it.
>
> Report every ledger ID as `FIXED`, `REJECTED`, or `BLOCKED`. For `FIXED`, list
> changed files and verification. For `REJECTED`, give concrete evidence that
> the finding was invalid. For `BLOCKED`, state the unresolved requirement.

Do not launch a second fixer after it returns.

## Report

Report the requested and completed critique rounds, findings per round, the
canonical ledger, every fix disposition, tests/builds run, remaining blocked
items, and final unstaged git state. Do not commit or stage unless explicitly
requested.
