#!/usr/bin/env bash

# Runs the macOS launcher through its local control flow with fake gh, ssh, and
# open commands. No Codespace is changed and Cursor is not actually launched.

set -euo pipefail

repo_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_dir/open-codespace-cursor-mac"
# shellcheck source=../open-codespace-common.sh
source "$repo_dir/open-codespace-common.sh"

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

fake_bin="$work_dir/bin"
fake_home="$work_dir/home"
gh_log="$work_dir/gh.log"
ssh_log="$work_dir/ssh.log"
open_log="$work_dir/open.log"
remote_prep_log="$work_dir/remote-prep.log"
mkdir -p "$fake_bin" "$fake_home"

name=fluffy-space-trout-rr59jjwv5cwqwg
url="https://$name.github.dev/"

cat >"$fake_bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$FAKE_GH_LOG"

if [[ "$1" == codespace && "$2" == view ]]; then
  printf '%s\towner/project\n' "$FAKE_CODESPACE_NAME"
elif [[ "$1" == codespace && "$2" == list ]]; then
  printf '%s\towner/project\tAvailable\t2026-08-23T20:00:00Z\n' \
    "$FAKE_CODESPACE_NAME"
elif [[ "$1" == codespace && "$2" == ssh ]]; then
  printf 'Host fake-%s\n' "$FAKE_CODESPACE_NAME"
  printf '  HostName codespaces.local\n'
  printf '  User codespace\n'
elif [[ "$1" == codespace && "$2" == ports ]]; then
  :
else
  printf 'Unexpected gh call: %s\n' "$*" >&2
  exit 1
fi
FAKE_GH
chmod +x "$fake_bin/gh"

cat >"$fake_bin/ssh" <<'FAKE_SSH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$FAKE_SSH_LOG"
if [[ "$2" == bash && "$3" == -s ]]; then
  cat >"$FAKE_REMOTE_PREP_LOG"
fi
FAKE_SSH
chmod +x "$fake_bin/ssh"

cat >"$fake_bin/open" <<'FAKE_OPEN'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == -Ra && "$2" == Cursor ]]; then
  exit 0
fi
printf '%s\n' "$@" >"$FAKE_OPEN_LOG"
FAKE_OPEN
chmod +x "$fake_bin/open"

run_launcher() {
  HOME="$fake_home" \
    PATH="$fake_bin:/usr/bin:/bin" \
    FAKE_CODESPACE_NAME="$name" \
    FAKE_GH_LOG="$gh_log" \
    FAKE_SSH_LOG="$ssh_log" \
    FAKE_REMOTE_PREP_LOG="$remote_prep_log" \
    FAKE_OPEN_LOG="$open_log" \
    /bin/bash "$script" "$@"
}

expected_name=$(codespace_name_from_input "$url")
if [[ "$expected_name" != "$name" ]]; then
  printf 'Expected %s to normalize to %s, got %s\n' \
    "$url" "$name" "$expected_name" >&2
  exit 1
fi

run_launcher "$url" >/dev/null

# A second run without an argument exercises the macOS-compatible replacement
# for mapfile/readarray and the one-Codespace non-interactive selection path.
run_launcher >/dev/null

expected_remote_url="cursor://vscode-remote/ssh-remote+fake-${name}/tmp/cursor-${name}.code-workspace?windowId=_blank"
[[ "$(sed -n '1p' "$open_log")" == "-a" ]]
[[ "$(sed -n '2p' "$open_log")" == "Cursor" ]]
[[ "$(sed -n '3p' "$open_log")" == "$expected_remote_url" ]]

grep -Fqx "codespace view -c $name --json name,repository --jq [.name, .repository] | @tsv" \
  "$gh_log"
grep -Fq 'codespace list --json name,repository,state,lastUsedAt' "$gh_log"
grep -Fq "codespace ports visibility 8069:private -c $name" "$gh_log"

[[ -f "$fake_home/.ssh/codespaces" ]]
[[ "$(grep -Fc 'Include ~/.ssh/codespaces' "$fake_home/.ssh/config")" == 1 ]]
for _ in 1 2 3 4 5 6 7 8 9 10; do
  grep -Fq "nohup bash '/tmp/open-codespace-bootstrap.sh'" "$ssh_log" \
    && break
  sleep 0.05
done
grep -Fq "nohup bash '/tmp/open-codespace-bootstrap.sh'" "$ssh_log"
grep -Fq 'remote_workspace=$1' "$remote_prep_log"
grep -Fq 'repository_name=$2' "$remote_prep_log"

printf 'macOS Cursor Codespace launcher tests passed.\n'
