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

gh() {
  local expected="codespace ports visibility 8069:public -c $name"
  local actual="$*"

  if [[ "$actual" != "$expected" ]]; then
    printf 'Expected gh call %q, got %q\n' "$expected" "$actual" >&2
    return 1
  fi
}

publish_output=$(publish_odoo_port "$name")
expected_url="https://$name-8069.app.github.dev/"
if [[ "$publish_output" != *"$expected_url"* ]]; then
  printf 'Expected publish output to contain %q, got %q\n' \
    "$expected_url" "$publish_output" >&2
  exit 1
fi

gh() {
  sleep 0.2
}
start_odoo_port_publication "$name" >/dev/null
publication_pid=$!
if ! kill -0 "$publication_pid" 2>/dev/null; then
  printf 'Expected Odoo port publication to continue in the background.\n' >&2
  exit 1
fi
wait "$publication_pid"
unset -f gh

printf 'Codespace launcher tests passed.\n'
