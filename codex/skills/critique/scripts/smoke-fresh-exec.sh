#!/usr/bin/env bash
# Smoke-test: one brand-new read-only codex exec critique pass.
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT="$(mktemp -t critique-smoke-XXXXXX).msg"
cleanup() { rm -f "$OUT"; }
trap cleanup EXIT

codex exec \
  --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  -C "$REPO_ROOT" \
  -o "$OUT" \
  'READ-ONLY critique smoke test. Run: git log -1 --oneline && git diff HEAD~1 --stat | head -15. Do not edit files. Final message: start with VERDICT: CLEAN or VERDICT: ERROR, then 2-4 short bullets.'

if ! grep -qE '^VERDICT: (CLEAN|FIXED|ERROR)' "$OUT"; then
  echo "FAIL: no VERDICT in $OUT" >&2
  cat "$OUT" >&2 || true
  exit 1
fi
echo "OK: nested codex exec produced:"
cat "$OUT"
