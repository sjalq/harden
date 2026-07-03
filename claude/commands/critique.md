---
description: Critically inspect code changes and determine if they accomplish their goal and if they have any serious deficits.
allowed-tools: Read, Bash, Grep, Glob
---

Critically inspect code changes and determine if they accomplish their goal and if they have any serious deficits.

**What to inspect:**
- If there are unstaged changes, review those (`git diff`)
- If there are only staged changes, review those (`git diff --staged`)
- If there are no pending changes, review the latest commit (`git diff HEAD~1`)
- If the user specifies a commit/range, use that (e.g., `git diff <commit>`)

**Focus areas:**
1. **Goal Achievement** - Do the changes accomplish what they appear to be trying to do?
2. **Error Handling** - Are errors handled robustly (Result types in Rust, Maybe/Result in Elm, try/catch where appropriate)?
3. **Logic Issues** - Any bugs, race conditions, or incorrect behavior?
4. **Security Concerns** - Any vulnerabilities introduced?
5. **Code Quality** - Proper logging, no unsafe unwraps/crashes, pure functional style where appropriate?
6. **Missing Pieces** - Any obvious gaps in implementation?

Provide a concise but thorough critique with specific file:line references and actionable recommendations.

**Note for orchestrators:** when this command is invoked as one pass of an automated loop (see `/harden`), it must run in a **fresh sub-agent** with no memory of prior passes — critiquing your own or a sibling agent's still-warm context reintroduces the bias a fresh review pass exists to remove.
