#!/usr/bin/env bash
# Installs the harden/critique skills for Claude Code and/or Codex CLI.
#
# Usage:
#   ./install.sh              # install for both Claude and Codex (whichever is present)
#   ./install.sh --claude     # Claude Code only
#   ./install.sh --codex      # Codex CLI only
#
# Safe to re-run: overwrites only the files this script installs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DO_CLAUDE=0
DO_CODEX=0
for arg in "$@"; do
  case "$arg" in
    --claude) DO_CLAUDE=1 ;;
    --codex) DO_CODEX=1 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done
if [ "$DO_CLAUDE" -eq 0 ] && [ "$DO_CODEX" -eq 0 ]; then
  DO_CLAUDE=1
  DO_CODEX=1
fi

if [ "$DO_CLAUDE" -eq 1 ]; then
  if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
    CLAUDE_COMMANDS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands"
    mkdir -p "$CLAUDE_COMMANDS_DIR"
    cp -v "$REPO_ROOT/claude/commands/harden.md" "$CLAUDE_COMMANDS_DIR/harden.md"
    cp -v "$REPO_ROOT/claude/commands/critique.md" "$CLAUDE_COMMANDS_DIR/critique.md"
    echo "Installed /harden and /critique into $CLAUDE_COMMANDS_DIR"
  else
    echo "Claude Code not detected (no 'claude' on PATH, no ~/.claude) — skipping. Pass --claude to force." >&2
  fi
fi

if [ "$DO_CODEX" -eq 1 ]; then
  if command -v codex >/dev/null 2>&1 || [ -d "$HOME/.codex" ]; then
    CODEX_SKILLS_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
    mkdir -p "$CODEX_SKILLS_DIR"
    rm -rf "$CODEX_SKILLS_DIR/harden" "$CODEX_SKILLS_DIR/critique"
    cp -Rv "$REPO_ROOT/codex/skills/harden" "$CODEX_SKILLS_DIR/harden"
    cp -Rv "$REPO_ROOT/codex/skills/critique" "$CODEX_SKILLS_DIR/critique"
    echo "Installed harden and critique skills into $CODEX_SKILLS_DIR"
    echo "Restart Codex (or start a new session) to pick them up."
  else
    echo "Codex CLI not detected (no 'codex' on PATH, no ~/.codex) — skipping. Pass --codex to force." >&2
  fi
fi
