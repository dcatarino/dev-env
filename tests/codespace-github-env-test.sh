#!/usr/bin/env bash

# Exercises the shell startup line that loads the Codespace's GitHub variables
# in shells without them (SSH sessions, and Herdr panes of a server started
# over SSH), against a fake Codespaces secrets file.

set -euo pipefail

repo_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

github_env_line=$(sed -n "s/^  github_env_line='\(.*\)'\$/\1/p" \
  "$repo_dir/codespace-bootstrap.sh")
[[ -n "$github_env_line" ]] || {
  printf 'Could not find the GitHub variables startup line\n' >&2
  exit 1
}
secrets=/workspaces/.codespaces/shared/.env-secrets
fake_secrets="$work_dir/.env-secrets"
startup_line=${github_env_line//"$secrets"/"$fake_secrets"}
[[ "$startup_line" != "$github_env_line" ]] || {
  printf 'The startup line does not read %s\n' "$secrets" >&2
  exit 1
}

encode() {
  printf '%s=%s\n' "$1" "$(printf %s "$2" | base64 | tr -d '\n')"
}

# Codespaces stores each value in base64. ghu_a and abcd encode with = and ==
# padding, which must survive. The last line has no newline.
content=$(
  encode CODESPACES true
  encode GITHUB_TOKEN ghu_a
  encode GITHUB_SERVER_URL https://github.com
  encode GIT_COMMITTER_NAME 'Diogo Catarino'
  encode RESTIC_PASSWORD not-a-github-value
  encode PATH /nowhere
  encode GITHUB_CODESPACE_TOKEN abcd
)
printf %s "$content" >"$fake_secrets"

# Runs the startup line in SHELL with the given env arguments and prints its
# status, the variables it may set, whether PATH changed, and any leftover
# loop variable.
run_line() {
  local shell=$1
  shift
  # shellcheck disable=SC2016
  env "$@" "$shell" -c 'old_path=$PATH'$'\n'"$startup_line"$'\n''exit_code=$?
    [ "$PATH" = "$old_path" ] && path=same || path=changed
    printf "%s|%s|%s|%s|%s|%s|%s|%s|%s" "$exit_code" "${GITHUB_TOKEN:-}" \
      "${GITHUB_SERVER_URL:-}" "${GIT_COMMITTER_NAME:-}" \
      "${GITHUB_CODESPACE_TOKEN:-}" "${RESTIC_PASSWORD:-}" "${CODESPACES:-}" \
      "$path" "${line:-}${key:-}"'
}

assert_result() {
  local description=$1 expected=$2 result=$3
  [[ "$result" == "$expected" ]] || {
    printf '%s: expected %s, got %s\n' "$description" "$expected" "$result" >&2
    exit 1
  }
}

unset_all=(-u GITHUB_TOKEN -u GITHUB_SERVER_URL -u GIT_COMMITTER_NAME
  -u GITHUB_CODESPACE_TOKEN -u RESTIC_PASSWORD -u CODESPACES)

for shell in bash zsh; do
  command -v "$shell" >/dev/null 2>&1 || continue

  # Without a token, only the GitHub variables are loaded.
  assert_result "$shell loads the GitHub variables" \
    "0|ghu_a|https://github.com|Diogo Catarino|abcd|||same|" \
    "$(run_line "$shell" "${unset_all[@]}")"

  # An editor terminal already has the token; nothing is loaded.
  assert_result "$shell keeps an existing token" \
    "0|ghu_editor||||||same|" \
    "$(run_line "$shell" "${unset_all[@]}" GITHUB_TOKEN=ghu_editor)"
done

# Outside a Codespace the file is missing and the line does nothing.
startup_line=${github_env_line//"$secrets"/"$work_dir/missing"}
assert_result "bash without a secrets file" "0|||||||same|" \
  "$(run_line bash "${unset_all[@]}")"

printf 'codespace-github-env tests passed\n'
