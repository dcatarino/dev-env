#!/usr/bin/env bash
# Remote Codespace installer for shared skills and agent instructions.
# Normally invoked automatically by either open-codespace launcher.
# Usage:  bash remote-codespace-setup.sh [project_dir]
#   project_dir (optional): an Odoo project to receive a Cursor .cursor/rules rule.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude/skills"
CODEX_DIR="$HOME/.agents/skills"
CURSOR_DIR="$HOME/.cursor/skills"
INSTRUCTIONS="$REPO/odoo-agent.md"
PROJECT_DIR="${1:-}"

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
  echo "        bash remote-codespace-setup.sh /workspaces/<project>"
fi

echo "Cursor global rule has no reliable file — for a global rule, paste"
echo "odoo-agent.md into Cursor Settings > Rules (User Rules)."

# --- GitHub CLI (gh) --------------------------------------------------------
# The odoo-pr skill needs `gh` (expects /usr/bin/gh), but codespaces don't
# always ship it. Install via GitHub's official apt repo. Auth is automatic
# through the codespace-injected GITHUB_TOKEN/GH_TOKEN, so no `gh auth login` is
# required. Best-effort: a failure here must not abort the rest of the setup.
install_gh() {
  if command -v gh >/dev/null 2>&1; then
    echo "gh already installed: $(gh --version | head -n1)"
    return 0
  fi
  echo "installing gh (GitHub CLI)..."
  sudo mkdir -p -m 755 /etc/apt/keyrings
  wget -nv -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y gh
  echo "installed: $(gh --version | head -n1)"
}

install_gh || echo "warning: gh install failed; open a PR manually or rerun setup"

# --- Browser automation (Playwright + Chromium) -----------------------------
# Browser-capable agents need a real browser runtime for autonomous Odoo UI
# checks. Pin Playwright because its package and downloaded browser build must
# stay compatible. A versioned marker keeps repeated launcher runs fast.
PLAYWRIGHT_VERSION=1.61.1
PLAYWRIGHT_READY="$HOME/.cache/dev-env/playwright-$PLAYWRIGHT_VERSION.ready"

install_playwright() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "npm is unavailable; cannot install Playwright" >&2
    return 1
  fi

  if command -v playwright >/dev/null 2>&1 \
    && [[ "$(playwright --version)" == "Version $PLAYWRIGHT_VERSION" ]] \
    && [[ -f "$PLAYWRIGHT_READY" ]]; then
    echo "playwright already installed: $(playwright --version)"
    return 0
  fi

  echo "installing Playwright $PLAYWRIGHT_VERSION and Chromium..."
  npm install -g "playwright@$PLAYWRIGHT_VERSION" || return 1
  hash -r
  playwright install --with-deps chromium || return 1
  mkdir -p "$(dirname "$PLAYWRIGHT_READY")"
  touch "$PLAYWRIGHT_READY"
  echo "installed: $(playwright --version) with Chromium"
}

install_playwright \
  || echo "warning: Playwright install failed; rerun setup before browser E2E testing"
