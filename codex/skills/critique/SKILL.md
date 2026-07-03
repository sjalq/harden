---
name: critique
description: Critically inspect code changes and determine if they accomplish their goal and if they have any serious deficits. Use for a single, thorough review pass — not a fix loop (see the `harden` skill for that).
metadata:
  short-description: One-pass code review with severity-tagged findings
---

# Critique (Codex)

Critically inspect code changes and determine if they accomplish their goal
and if they have any serious deficits. This is a single review pass — it
does not fix anything and it does not loop. For an automated fix loop, use
the `harden` skill instead.

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

## Running as a fresh, unbiased pass

If you (the calling agent) have been reading or writing the code under
review earlier in this same conversation, your judgment is contaminated by
that context. For an unbiased pass, delegate the actual critique to a
brand-new subprocess instead of reviewing in-session:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
OUT="$(mktemp -t critique-XXXX).msg"

codex exec \
  --skip-git-repo-check \
  -s read-only \
  -C "$REPO_ROOT" \
  -o "$OUT" \
  "Critically inspect the code changes (git diff, or git diff --staged if
   nothing unstaged, or git diff HEAD~1 if nothing pending). Classify each
   issue HIGH / MEDIUM / LOW across: goal achievement, error handling,
   logic issues, security concerns, code quality, missing pieces. Do NOT
   edit any files — this is read-only review. Report findings with
   file:line references."

cat "$OUT"
```

Use `-s read-only` here (unlike `harden`, which needs `workspace-write` to
apply fixes) since a pure critique pass should never modify the repo. This
is exactly what the `harden` skill does for each loop iteration — see that
skill if you need fix-and-reloop behavior instead of a single report.
