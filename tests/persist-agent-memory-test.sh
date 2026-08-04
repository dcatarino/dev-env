#!/usr/bin/env bash
# Exercises persist-agent-memory.sh against a fake HOME/workspaces tree. The
# script deletes the live memory directory after copying it, so the cases that
# matter are: existing memory is preserved, an already-persisted file is never
# clobbered by a Codespace-local one, non-workspace projects are left alone,
# and reruns are idempotent.

set -euo pipefail

repo_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_dir/persist-agent-memory.sh"

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

store="$work_dir/store"
projects="$work_dir/projects"
workspaces="$work_dir/workspaces"

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

run_script() {
  MEMORY_STORE="$store" PROJECTS_DIR="$projects" WORKSPACES_DIR="$workspaces" \
    bash "$script" >/dev/null
}

encoded_for() { printf '%s' "${1//\//-}"; }

# A tracked Git project with memory Claude already wrote locally.
adopted_project="$workspaces/360_generic"
adopted_encoded=$(encoded_for "$adopted_project")
mkdir -p "$adopted_project"
git -C "$adopted_project" init -q
mkdir -p "$projects/$adopted_encoded/memory"
printf 'local version\n' >"$projects/$adopted_encoded/memory/MEMORY.md"
printf 'odoo 16 here\n' >"$projects/$adopted_encoded/memory/customer-version.md"

# An already-persisted file that must win over the Codespace-local copy.
mkdir -p "$store/$adopted_encoded"
printf 'persisted version\n' >"$store/$adopted_encoded/MEMORY.md"

# A tracked Git project with no memory yet — should be pre-seeded.
fresh_project="$workspaces/Integrations-Acme"
fresh_encoded=$(encoded_for "$fresh_project")
mkdir -p "$fresh_project"
git -C "$fresh_project" init -q

# A plain directory that is not a Git repository — must be skipped.
mkdir -p "$workspaces/not-a-repo"

# A project outside the workspaces root — must never be adopted.
outside_encoded="-home-someone-personal"
mkdir -p "$projects/$outside_encoded/memory"
printf 'private notes\n' >"$projects/$outside_encoded/memory/MEMORY.md"

run_script

# 1. The local-only file was carried into the store.
[[ -f "$store/$adopted_encoded/customer-version.md" ]] \
  || fail 'Adopted memory file was not persisted into the store.'

# 2. The already-persisted file was not clobbered.
actual=$(<"$store/$adopted_encoded/MEMORY.md")
[[ "$actual" == 'persisted version' ]] \
  || fail "Persisted MEMORY.md was overwritten; got: $actual"

# 3. The live path is now a symlink into the store.
live="$projects/$adopted_encoded/memory"
[[ -L "$live" ]] || fail 'Adopted memory path is not a symlink.'
[[ "$(readlink "$live")" == "$store/$adopted_encoded" ]] \
  || fail "Adopted symlink points at $(readlink "$live")"

# 4. Reads through the symlink still see the memory.
[[ -f "$live/customer-version.md" ]] \
  || fail 'Memory is not readable through the adopted symlink.'

# 5. The fresh project was pre-seeded with a symlink.
fresh_live="$projects/$fresh_encoded/memory"
[[ -L "$fresh_live" ]] || fail 'Fresh project was not pre-seeded with a symlink.'
[[ "$(readlink "$fresh_live")" == "$store/$fresh_encoded" ]] \
  || fail "Fresh symlink points at $(readlink "$fresh_live")"

# 6. The non-Git directory was skipped.
[[ ! -e "$projects/$(encoded_for "$workspaces/not-a-repo")" ]] \
  || fail 'A non-Git directory was linked.'

# 7. A project outside the workspaces root was left untouched.
outside_live="$projects/$outside_encoded/memory"
[[ -d "$outside_live" && ! -L "$outside_live" ]] \
  || fail 'A project outside the workspaces root was adopted.'
[[ ! -e "$store/$outside_encoded" ]] \
  || fail 'A project outside the workspaces root was copied into the store.'

# 8. Rerunning changes nothing and loses nothing.
before=$(find "$store" | sort)
run_script
after=$(find "$store" | sort)
[[ "$before" == "$after" ]] || fail 'Rerun changed the persisted store.'
[[ "$(<"$store/$adopted_encoded/MEMORY.md")" == 'persisted version' ]] \
  || fail 'Rerun clobbered the persisted MEMORY.md.'

# 9. A rebuild (live state wiped, store intact) restores through the symlink.
rm -rf "$projects"
run_script
[[ -f "$projects/$adopted_encoded/memory/customer-version.md" ]] \
  || fail 'Memory did not survive a simulated Codespace rebuild.'

printf 'persist-agent-memory tests passed.\n'
