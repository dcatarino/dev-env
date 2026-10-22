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
printf '%s\n' "${HERDR_SESSION:-<none>}" >>"$FAKE_WORK/sessions"
case "${1:-} ${2:-}" in
  "status server") printf 'status: running\n' ;;
  "agent list")
    printf '{"result":{"agents":[{"name":"odoo-repo-18","agent":"claude","agent_status":"working","cwd":"/w","pane_id":"w1:p1"}]}}\n'
    ;;
  "workspace create")
    printf '{"result":{"workspace":{"workspace_id":"w2"},"root_pane":{"pane_id":"w2:p1","terminal_id":"term_new"}}}\n'
    ;;
  "workspace focus"|"agent focus") printf '{"result":{}}\n' ;;
  " ")
    # The Herdr client: record the config it was given.
    printf 'client config=%s\n' "${HERDR_CONFIG_PATH:-}" >>"$FAKE_HERDR_LOG"
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
  *) printf 'unexpected herdr call: %s\n' "$*" >&2; exit 1 ;;
esac
FAKE_HERDR
chmod +x "$fake_bin/herdr"

# The caller's own Herdr or Codespace variables must not leak in; extra_env
# sets them per case.
extra_env=()
run_herd() {
  (cd "$work_dir/Odoo Repo.18" \
    && env -u HERDR_ENV -u HERDR_SESSION -u CODESPACES -u TERM_PROGRAM \
      PATH="$fake_bin:/usr/bin:/bin" FAKE_WORK="$work_dir" \
      FAKE_HERDR_LOG="$herdr_log" ${extra_env[@]+"${extra_env[@]}"} \
      bash "${herd_path:-$script}" "$@")
}

# Prints the distinct sessions herd used since the last reset.
sessions_used() {
  sort -u "$work_dir/sessions"
  : >"$work_dir/sessions"
}

# A default name comes from the folder, skips live names, and the agent
# arguments are passed through after --.
run_herd claude -- --model opus
grep -Fq "workspace create --cwd $work_dir/Odoo Repo.18 --label odoo-repo-18-2 --no-focus" \
  "$herdr_log" || fail "workspace was not created with a free folder-based name"
[[ "$(grep -c '^agent start odoo-repo-18-2 --kind claude --pane w2:p1 -- --model opus$' \
  "$herdr_log")" == 2 ]] || fail "agent start was not retried with the same arguments"
# A Herdr client, not a direct terminal attach, which would fix the agent's
# terminal size to this terminal for every other client. The client opens on
# the focused workspace, so the new one is focused last.
[[ "$(tail -n 3 "$herdr_log")" == "workspace focus w2"$'\n\n'"client config=$repo_dir/herd-client.toml" ]] \
  || fail "did not open the new agent's workspace in a Herdr client with herd-client.toml"
grep -Fq 'attach' "$herdr_log" && fail "attached directly to the agent's terminal"

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

# remote-codespace-setup.sh installs herd as a symlink; the client config is
# still found next to the real script.
: >"$herdr_log"
ln -s "$script" "$work_dir/herd-link"
herd_path="$work_dir/herd-link" run_herd attach odoo-repo-18
[[ "$(tail -n 3 "$herdr_log")" == "agent focus odoo-repo-18"$'\n\n'"client config=$repo_dir/herd-client.toml" ]] \
  || fail "attach did not open the agent in a Herdr client"

listing=$(run_herd ls)
grep -Fq $'odoo-repo-18\tclaude\tworking\t/w' <<<"$listing" || fail "ls did not list agents"

# Outside a Codespace, herd uses the herdr-codespaces window's session; in a
# Codespace the server's default; a session that is already set is kept.
[[ "$(sessions_used)" == codespaces ]] \
  || fail "a computer's agents did not go to the herdr-codespaces session"
extra_env=(CODESPACES=true)
run_herd ls >/dev/null
[[ "$(sessions_used)" == "<none>" ]] || fail "a Codespace did not use its default session"
extra_env=(HERDR_SESSION=other)
run_herd ls >/dev/null
[[ "$(sessions_used)" == other ]] || fail "an explicit HERDR_SESSION was not kept"

# Inside a Herdr pane, focusing switches that window to the agent; opening a
# client there would nest Herdr in its own pane.
: >"$herdr_log"
rm -f "$work_dir/start-count"
extra_env=(HERDR_ENV=1 HERDR_SESSION=codespaces TERM_PROGRAM=herdr)
output=$(run_herd claude inside)
[[ "$(tail -n 1 "$herdr_log")" == "workspace focus w2" ]] \
  || fail "inside Herdr, the new agent's workspace was not focused last"
grep -Fq 'client config=' "$herdr_log" && fail "inside Herdr, a nested client was opened"
grep -Fq 'switched this Herdr window' <<<"$output" || fail "inside Herdr, herd did not say it switched"
: >"$herdr_log"
run_herd attach odoo-repo-18 >/dev/null
[[ "$(cat "$herdr_log")" == "status server"$'\n'"agent focus odoo-repo-18" ]] \
  || fail "inside Herdr, attach did not only focus the agent"

# A Cursor window opened from a Herdr pane inherits the pane's variables, but
# its terminal is not a pane: herd opens a client there, in the same session.
: >"$herdr_log"
rm -f "$work_dir/start-count"
extra_env=(HERDR_ENV=1 HERDR_PANE_ID=w1:p1 HERDR_SESSION=codespaces TERM_PROGRAM=vscode)
output=$(run_herd claude cursor)
[[ "$(tail -n 3 "$herdr_log")" == "workspace focus w2"$'\n\n'"client config=$repo_dir/herd-client.toml" ]] \
  || fail "with inherited Herdr variables, herd did not open a Herdr client"
grep -Fq 'switched this Herdr window' <<<"$output" && fail "a Cursor terminal passed for a Herdr pane"
[[ "$(sessions_used)" == codespaces ]] || fail "the inherited Herdr session was not kept"
extra_env=()

printf 'herd tests passed.\n'
