#!/usr/bin/env bash

# Exercises the browser-editor BROWSER wrapper and the shell startup line that
# selects it, with a fake VS Code helper. No browser is opened.

set -euo pipefail

repo_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

opened="$work_dir/opened.log"
helper="$work_dir/vscode-browser.sh"
cat >"$helper" <<'FAKE_HELPER'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_OPENED_LOG"
FAKE_HELPER
chmod +x "$helper"

open_url() {
  DEV_ENV_VSCODE_BROWSER="$helper" FAKE_OPENED_LOG="$opened" \
    bash "$repo_dir/codespace-browser" "$1" 2>/dev/null
}

assert_refused() {
  : >"$opened"
  if open_url "$1"; then
    printf 'Expected the wrapper to refuse %s\n' "$1" >&2
    exit 1
  fi
  [[ ! -s "$opened" ]] || {
    printf 'Refused URL still reached the helper: %s\n' "$1" >&2
    exit 1
  }
}

assert_opened() {
  : >"$opened"
  open_url "$1"
  [[ "$(<"$opened")" == "$1" ]] || {
    printf 'Expected the helper to open %s\n' "$1" >&2
    exit 1
  }
}

query='code=true&client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e&response_type=code'

# Claude Code's automatic sign-in URLs cannot complete in the browser editor.
assert_refused "https://claude.com/cai/oauth/authorize?${query}&redirect_uri=http%3A%2F%2Flocalhost%3A35323%2Fcallback&state=x"
assert_refused "https://claude.com/cai/oauth/authorize?${query}&redirect_uri=http://localhost:35323/callback&state=x"
assert_refused "https://platform.claude.com/oauth/authorize?${query}&redirect_uri=http%3a%2f%2flocalhost%3a4000%2fcallback"

# The manual sign-in URL, other Claude links, and other sites still open.
assert_opened "https://claude.com/cai/oauth/authorize?${query}&redirect_uri=https%3A%2F%2Fplatform.claude.com%2Foauth%2Fcode%2Fcallback&state=x"
assert_opened "https://claude.ai/settings"
assert_opened "https://example.com/authorize?redirect_uri=http%3A%2F%2Flocalhost%3A1%2Fcallback"

# Without the original helper the wrapper fails instead of looping.
if bash "$repo_dir/codespace-browser" https://example.com/ 2>/dev/null; then
  printf 'Expected a failure without DEV_ENV_VSCODE_BROWSER\n' >&2
  exit 1
fi

# The startup line must select the wrapper only for VS Code's Codespace helper.
browser_line=$(sed -n "s/^  browser_line='\(.*\)'\$/\1/p" \
  "$repo_dir/codespace-bootstrap.sh")
[[ -n "$browser_line" ]] || {
  printf 'Could not find the BROWSER startup line\n' >&2
  exit 1
}

fake_home="$work_dir/home"
mkdir -p "$fake_home/.local/bin"
ln -s "$repo_dir/codespace-browser" "$fake_home/.local/bin/codespace-browser"
vscode_helper=/vscode/bin/linux-x64/abc/bin/helpers/browser.sh
cursor_helper=/home/codespace/.cursor-server/bin/abc/bin/helpers/browser.sh

assert_startup() {
  local shell=$1
  local initial=$2
  local expected_browser=$3
  local expected_original=$4
  local result

  # Source the line twice, as nested shells do, to check it stays stable.
  # shellcheck disable=SC2016
  result=$(HOME="$fake_home" BROWSER="$initial" "$shell" -c \
    "$browser_line"$'\n'"$browser_line"$'\n''printf "%s|%s" "${BROWSER:-}" "${DEV_ENV_VSCODE_BROWSER:-}"')
  [[ "$result" == "$expected_browser|$expected_original" ]] || {
    printf '%s with BROWSER=%s gave %s\n' "$shell" "$initial" "$result" >&2
    exit 1
  }
}

for shell in bash zsh; do
  command -v "$shell" >/dev/null 2>&1 || continue
  assert_startup "$shell" "$vscode_helper" \
    "$fake_home/.local/bin/codespace-browser" "$vscode_helper"
  assert_startup "$shell" "$cursor_helper" "$cursor_helper" ""
  assert_startup "$shell" "" "" ""
done

printf 'codespace-browser tests passed\n'
