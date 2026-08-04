#!/usr/bin/env bash
# Print "reload" when installed agent context changed since the last check.
set -euo pipefail

repo=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"}
state_file=${2:-"$HOME/.cache/dev-env/agent-context.sha256"}

context_hash=$(
  {
    find "$repo" -name SKILL.md -not -path '*/.git/*' -print0
    printf '%s\0' "$repo/odoo-agent.md"
  } \
    | sort -z \
    | while IFS= read -r -d '' file; do
        file_hash=$(sha256sum "$file")
        printf '%s\0%s\n' "${file#"$repo"/}" "${file_hash%% *}"
      done \
    | sha256sum \
    | awk '{print $1}'
)

previous_hash=
[[ -f "$state_file" ]] && previous_hash=$(<"$state_file")

mkdir -p "$(dirname "$state_file")"
printf '%s\n' "$context_hash" >"$state_file"

if [[ "$context_hash" == "$previous_hash" ]]; then
  printf 'current\n'
else
  printf 'reload\n'
fi
