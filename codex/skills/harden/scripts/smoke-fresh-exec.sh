#!/usr/bin/env bash
# Smoke-test: one brand-new codex exec can run (the building block for each
# read-only reviewer and the sole fixer). Exit 0 only if it returns a verdict.
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT="$(mktemp -t harden-smoke-XXXXXX).msg"
cleanup() { rm -f "$OUT"; }
trap cleanup EXIT

codex exec \
  --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  -C "$REPO_ROOT" \
  -o "$OUT" \
  'READ-ONLY harness smoke test. Run: git rev-parse --show-toplevel && git log -1 --oneline. Do not edit files. Final message MUST start with VERDICT: CLEAN or VERDICT: ERROR.'

if ! grep -qE '^VERDICT: (CLEAN|FIXED|ERROR)' "$OUT"; then
  echo "FAIL: no VERDICT in $OUT" >&2
  cat "$OUT" >&2 || true
  exit 1
fi
echo "OK: nested codex exec produced:"
cat "$OUT"
