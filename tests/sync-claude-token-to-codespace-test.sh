#!/usr/bin/env bash
# Exercises the non-interactive path only (explicit repos, token already
# exported), since the interactive selector and hidden prompt both require a
# real /dev/tty. Verifies the token reaches `gh` only via stdin, never as an
# argument, and never appears in the script's own stdout.

set -euo pipefail

repo_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_dir/sync-claude-token-to-codespace"

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

gh_call_log="$work_dir/gh-call.log"
gh_stdin_log="$work_dir/gh-stdin.log"
fake_gh="$work_dir/gh"

cat >"$fake_gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$gh_call_log"
cat > "$gh_stdin_log"
EOF
chmod +x "$fake_gh"

token=test-token-value-should-never-appear-in-argv-or-stdout

run_script() {
  PATH="$work_dir:$PATH" CLAUDE_CODE_OAUTH_TOKEN="$token" \
    bash "$script" "$@"
}

output=$(run_script owner/repo1 owner/repo2)

expected_call='secret set CLAUDE_CODE_OAUTH_TOKEN --user --repos owner/repo1,owner/repo2'
actual_call=$(<"$gh_call_log")
if [[ "$actual_call" != "$expected_call" ]]; then
  printf 'Expected gh call %q, got %q\n' "$expected_call" "$actual_call" >&2
  exit 1
fi

actual_stdin=$(<"$gh_stdin_log")
if [[ "$actual_stdin" != "$token" ]]; then
  printf 'Expected token on gh stdin, got %q\n' "$actual_stdin" >&2
  exit 1
fi

if [[ "$output" == *"$token"* ]]; then
  printf 'Token leaked into script output: %q\n' "$output" >&2
  exit 1
fi

if [[ "$actual_call" == *"$token"* ]]; then
  printf 'Token leaked into gh arguments: %q\n' "$actual_call" >&2
  exit 1
fi

printf 'sync-claude-token-to-codespace tests passed.\n'
