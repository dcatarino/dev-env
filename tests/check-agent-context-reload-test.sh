#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

repo="$work_dir/repo"
state="$work_dir/cache/context.sha256"
mkdir -p "$repo/skills/example"
printf 'instructions\n' >"$repo/odoo-agent.md"
printf 'skill one\n' >"$repo/skills/example/SKILL.md"

assert_output() {
  local expected=$1
  local actual
  actual=$(bash "$ROOT/check-agent-context-reload.sh" "$repo" "$state")
  [[ "$actual" == "$expected" ]] || {
    printf 'expected %q, got %q\n' "$expected" "$actual" >&2
    exit 1
  }
}

assert_output reload
assert_output current

printf 'skill two\n' >"$repo/skills/example/SKILL.md"
assert_output reload
assert_output current

printf 'new instructions\n' >"$repo/odoo-agent.md"
assert_output reload

mkdir -p "$repo/skills/another"
printf 'another skill\n' >"$repo/skills/another/SKILL.md"
assert_output reload

printf 'check-agent-context-reload tests passed\n'
