#!/usr/bin/env bash
# Persist Claude Code's auto-memory into this repository.
#
# Claude writes memory to ~/.claude/projects/<encoded-project-path>/memory/,
# which a Codespace rebuild discards along with the rest of $HOME. This
# symlinks those directories into dev-env/memory/ so learned facts survive.
#
# The repository is private because of what these files contain; read
# memory/README.md before changing that.
#
# Normally invoked by remote-codespace-setup.sh. Safe to rerun.
#
# Test hooks (defaults are the real paths):
#   MEMORY_STORE    where memory is persisted   (default <repo>/memory)
#   PROJECTS_DIR    Claude's project state      (default ~/.claude/projects)
#   WORKSPACES_DIR  Codespace project root      (default /workspaces)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_STORE="${MEMORY_STORE:-$REPO/memory}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/.claude/projects}"
WORKSPACES_DIR="${WORKSPACES_DIR:-/workspaces}"

mkdir -p "$MEMORY_STORE"

# Adopt any real memory directory Claude already created for a project under
# the workspaces root. This is also the correctness backstop for the encoded
# name derived below: if that derivation is ever wrong, Claude created the
# right directory itself and this takes it over on the next run.
adopt_existing() {
  local live stored encoded

  for live in "$PROJECTS_DIR"/*/memory; do
    [[ -d "$live" && ! -L "$live" ]] || continue

    encoded="$(basename "$(dirname "$live")")"
    # Only adopt projects that live under the workspaces root.
    [[ "$encoded" == "${WORKSPACES_DIR//\//-}"-* ]] || continue

    stored="$MEMORY_STORE/$encoded"
    mkdir -p "$stored"
    # Never clobber an already-persisted file with a Codespace-local one.
    cp -a -n "$live"/. "$stored"/ 2>/dev/null || true
    rm -rf "$live"
    ln -sfn "$stored" "$live"
    echo "adopted memory: $encoded"
  done
}

# Pre-seed a link for every Git repository under the workspaces root, so memory
# is persisted from the very first session rather than only from the next
# launcher run. Claude encodes a project path by replacing '/' with '-'.
link_projects() {
  local project encoded stored live

  [[ -d "$WORKSPACES_DIR" ]] || {
    echo "$WORKSPACES_DIR is unavailable; skipping memory pre-seed"
    return 0
  }

  for project in "$WORKSPACES_DIR"/*/; do
    project="${project%/}"
    [[ -d "$project" ]] || continue
    git -C "$project" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue

    encoded="${project//\//-}"
    stored="$MEMORY_STORE/$encoded"
    live="$PROJECTS_DIR/$encoded/memory"

    mkdir -p "$stored" "$(dirname "$live")"

    if [[ -L "$live" ]]; then
      ln -sfn "$stored" "$live"        # refresh, in case the checkout moved
    elif [[ ! -e "$live" ]]; then
      ln -sfn "$stored" "$live"
      echo "linked memory: $encoded"
    fi
  done
}

adopt_existing
link_projects

echo "Memory persisted to $MEMORY_STORE"
