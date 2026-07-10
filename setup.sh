#!/usr/bin/env bash
# Install shared development helpers, skills, and agent instructions.
# Usage:  bash setup.sh [project_dir]
#   project_dir (optional): an Odoo project to receive a Cursor .cursor/rules rule.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude/skills"
CODEX_DIR="$HOME/.agents/skills"
CURSOR_DIR="$HOME/.cursor/skills"
LOCAL_BIN="$HOME/.local/bin"
INSTRUCTIONS="$REPO/odoo-agent.md"
OPEN_CODESPACE="$REPO/open-codespace"
PROJECT_DIR="${1:-}"

mkdir -p "$CLAUDE_DIR" "$CODEX_DIR" "$CURSOR_DIR" "$LOCAL_BIN"

# Keep the command linked to this checkout so pulling dev-env updates it.
ln -sfn "$OPEN_CODESPACE" "$LOCAL_BIN/open-codespace"
echo "installed: $LOCAL_BIN/open-codespace"

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

echo "Done (skills). Claude -> $CLAUDE_DIR   Codex -> $CODEX_DIR   Cursor -> $CURSOR_DIR"

# --- Agent instructions (odoo-agent.md) -------------------------------------
# Claude (~/.claude/CLAUDE.md) and Codex (~/.codex/AGENTS.md) read a clean
# markdown file, so symlink it for live updates. Back up any pre-existing real
# file first so we never clobber an existing global memory/instructions file.
link_instruction() {                       # $1 = target path
  local target="$1"
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mv "$target" "$target.bak.$(date +%s)"
    echo "backed up existing $target -> $target.bak.*"
  fi
  ln -sfn "$INSTRUCTIONS" "$target"
  echo "installed: $target"
}

link_instruction "$HOME/.claude/CLAUDE.md"
link_instruction "$HOME/.codex/AGENTS.md"

# Cursor: no reliable global rules *file* — the reliable global path is the
# Settings UI. The reliable file-based option is a project-level rule, which
# needs frontmatter (so it's generated, not symlinked). Provide a project dir
# to install it; otherwise it's skipped.
if [ -n "$PROJECT_DIR" ]; then
  rule="$PROJECT_DIR/.cursor/rules/odoo-agent.mdc"
  mkdir -p "$(dirname "$rule")"
  { printf -- '---\ndescription: Odoo developer agent instructions\nalwaysApply: true\n---\n\n'; cat "$INSTRUCTIONS"; } > "$rule"
  echo "installed: $rule (generated; re-run after editing odoo-agent.md)"
else
  echo "Cursor: no project dir given — pass one to install a project rule:"
  echo "        bash setup.sh /workspaces/<project>"
fi

echo "Cursor global rule has no reliable file — for a global rule, paste"
echo "odoo-agent.md into Cursor Settings > Rules (User Rules)."
