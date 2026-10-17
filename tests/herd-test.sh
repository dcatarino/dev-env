#!/usr/bin/env bash

# Runs herd against a fake herdr command. No Herdr server or agent is started.

set -euo pipefail

repo_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_dir/herd"

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

fake_bin="$work_dir/bin"
herdr_log="$work_dir/herdr.log"
mkdir -p "$fake_bin" "$work_dir/Odoo Repo.18"

fail() {
  printf 'herd test: %s\n' "$1" >&2
  exit 1
}

# The fake server is running and already has an agent named odoo-repo-18. The
# first `agent start` on a new pane reports a busy pane, as a real pane does
# until its shell is ready.
cat >"$fake_bin/herdr" <<'FAKE_HERDR'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_HERDR_LOG"
case "$1 ${2:-}" in
  "status server") printf 'status: running\n' ;;
  "agent list")
    printf '{"result":{"agents":[{"name":"odoo-repo-18","agent":"claude","agent_status":"working","cwd":"/w","pane_id":"w1:p1"}]}}\n'
    ;;
  "workspace create")
    printf '{"result":{"root_pane":{"pane_id":"w2:p1","terminal_id":"term_new"}}}\n'
    ;;
  "agent start")
    count_file="$FAKE_WORK/start-count"
    count=$(( $(cat "$count_file" 2>/dev/null || echo 0) + 1 ))
    printf '%s' "$count" >"$count_file"
    if (( count == 1 )); then
      printf '{"error":{"code":"agent_pane_busy","message":"busy"}}\n' >&2
      exit 1
    fi
    printf '{"result":{"type":"agent_started"}}\n'
    ;;
  "terminal attach"|"agent attach") ;;
  *) printf 'unexpected herdr call: %s\n' "$*" >&2; exit 1 ;;
esac
FAKE_HERDR
chmod +x "$fake_bin/herdr"

run_herd() {
  (cd "$work_dir/Odoo Repo.18" \
    && PATH="$fake_bin:/usr/bin:/bin" FAKE_WORK="$work_dir" \
      FAKE_HERDR_LOG="$herdr_log" bash "$script" "$@")
}

# A default name comes from the folder, skips live names, and the agent
# arguments are passed through after --.
run_herd claude -- --model opus
grep -Fq "workspace create --cwd $work_dir/Odoo Repo.18 --label odoo-repo-18-2 --no-focus" \
  "$herdr_log" || fail "workspace was not created with a free folder-based name"
[[ "$(grep -c '^agent start odoo-repo-18-2 --kind claude --pane w2:p1 -- --model opus$' \
  "$herdr_log")" == 2 ]] || fail "agent start was not retried with the same arguments"
grep -Fqx 'terminal attach term_new' "$herdr_log" || fail "did not attach to the new agent"

# Codex is selected explicitly and a name may be given.
: >"$herdr_log"
rm -f "$work_dir/start-count"
run_herd codex reviewer
grep -Fq 'agent start reviewer --kind codex --pane w2:p1 --' "$herdr_log" \
  || fail "codex agent was not started with the given name"

# Live names and invalid names are refused before creating anything.
: >"$herdr_log"
if run_herd claude odoo-repo-18 2>/dev/null; then
  fail "a duplicate live agent name was accepted"
fi
if run_herd claude Bad.Name 2>/dev/null; then
  fail "an invalid agent name was accepted"
fi
grep -Fq 'workspace create' "$herdr_log" && fail "a workspace was created for a refused name"

run_herd attach odoo-repo-18
grep -Fqx 'agent attach odoo-repo-18' "$herdr_log" || fail "attach did not target the agent"

listing=$(run_herd ls)
grep -Fq $'odoo-repo-18\tclaude\tworking\t/w' <<<"$listing" || fail "ls did not list agents"

printf 'herd tests passed.\n'
