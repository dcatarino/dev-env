#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../open-codespace-common.sh
source "$repo_dir/open-codespace-common.sh"

assert_normalizes() {
  local expected=$1
  local input=$2
  local actual

  actual=$(codespace_name_from_input "$input")
  if [[ "$actual" != "$expected" ]]; then
    printf 'Expected %q to normalize to %q, got %q\n' \
      "$input" "$expected" "$actual" >&2
    return 1
  fi
}

assert_rejected() {
  local input=$1

  if codespace_name_from_input "$input" >/dev/null; then
    printf 'Expected %q to be rejected\n' "$input" >&2
    return 1
  fi
}

name=potential-spork-777gprjr7pphr79

assert_normalizes "$name" "$name"

assert_normalizes "$name" "https://$name.github.dev"
assert_normalizes "$name" "https://$name.github.dev/"
assert_normalizes "$name" "https://$name.github.dev/?editor=cursor"
assert_normalizes "$name" "https://$name.github.dev/#workspace"

assert_normalizes "$name" "https://github.com/codespaces/$name"
assert_normalizes "$name" "https://github.com/codespaces/$name/"
assert_normalizes "$name" "https://github.com/codespaces/$name?editor=cursor"
assert_normalizes "$name" "https://github.com/codespaces/$name/#workspace"

assert_rejected "https://$name.github.dev/workspace"
assert_rejected "https://github.com/codespaces/$name/workspace"
assert_rejected "http://$name.github.dev/"
assert_rejected "https://example.com/codespaces/$name"

printf 'Codespace input tests passed.\n'
