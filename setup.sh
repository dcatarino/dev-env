#!/usr/bin/env bash
# Install all skills in this repo for Claude Code, Codex, and Cursor.
# Usage:  bash setup.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude/skills"
CODEX_DIR="$HOME/.agents/skills"
CURSOR_DIR="$HOME/.cursor/skills"

mkdir -p "$CLAUDE_DIR" "$CODEX_DIR" "$CURSOR_DIR"

# Every directory that contains a SKILL.md is a skill.
find "$REPO" -name SKILL.md -not -path '*/.git/*' | while read -r skill; do
  dir="$(dirname "$skill")"
  name="$(basename "$dir")"

  # All three tools use a folder-per-skill layout; symlink for live updates.
  ln -sfn "$dir" "$CLAUDE_DIR/$name"
  ln -sfn "$dir" "$CODEX_DIR/$name"
  ln -sfn "$dir" "$CURSOR_DIR/$name"

  echo "installed: $name"
done

echo "Done. Claude -> $CLAUDE_DIR   Codex -> $CODEX_DIR   Cursor -> $CURSOR_DIR"
