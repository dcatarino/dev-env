#!/usr/bin/env bash

# Runs herdr-codespaces sync against fake gh and herdr commands. No Codespace
# or Herdr machine is changed.

set -euo pipefail

repo_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_dir/herdr-codespaces"

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

fake_bin="$work_dir/bin"
fake_home="$work_dir/home"
herdr_log="$work_dir/herdr.log"
gh_log="$work_dir/gh.log"
mkdir -p "$fake_bin" "$fake_home"

fail() {
  printf 'herdr-codespaces test: %s\n' "$1" >&2
  exit 1
}

# Codespaces: alpha is running and not yet a machine, beta is running and its
# machine was disabled by an earlier sync when it stopped, zeta is running but
# its machine was disabled by the user, gamma is stopped with an enabled
# machine, delta's Codespace was deleted, epsilon is running but herdr add
# fails there, and eta is running with two machines, which syncs that ran at
# once used to add.
cat >"$work_dir/codespaces.json" <<'JSON'
[
  {"name": "alpha-cs-x1", "repository": "360ERP/mattsleeps", "state": "Available"},
  {"name": "beta-cs-x2", "repository": "360ERP/beautyplaza", "state": "Available"},
  {"name": "gamma-cs-x3", "repository": "360ERP/stas", "state": "Shutdown"},
  {"name": "epsilon-cs-x5", "repository": "360ERP/vyta", "state": "Available"},
  {"name": "zeta-cs-x6", "repository": "360ERP/stoov", "state": "Available"},
  {"name": "eta-cs-x7", "repository": "360ERP/pauw", "state": "Available"}
]
JSON
cat >"$work_dir/machines.json" <<'JSON'
[
  {"id": "ep_beta", "label": "beautyplaza (beta-cs)", "target": "herdr-cs.beta-cs-x2",
   "session": "default", "enabled": false, "selected": false},
  {"id": "ep_gamma", "label": "stas (gamma-cs)", "target": "herdr-cs.gamma-cs-x3",
   "session": "default", "enabled": true, "selected": false},
  {"id": "ep_delta", "label": "old (delta-cs)", "target": "herdr-cs.delta-cs-x4",
   "session": "default", "enabled": true, "selected": false},
  {"id": "ep_zeta", "label": "stoov (zeta-cs)", "target": "herdr-cs.zeta-cs-x6",
   "session": "default", "enabled": false, "selected": false},
  {"id": "ep_mine", "label": "my server", "target": "workbox",
   "session": "default", "enabled": true, "selected": false},
  {"id": "ep_eta_a", "label": "pauw (eta-cs)", "target": "herdr-cs.eta-cs-x7",
   "session": "default", "enabled": true, "selected": false},
  {"id": "ep_eta_b", "label": "pauw (eta-cs)", "target": "herdr-cs.eta-cs-x7",
   "session": "default", "enabled": true, "selected": true}
]
JSON

cat >"$fake_bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
if [[ "$1 $2" == "codespace list" ]]; then
  if [[ -e "$FAKE_WORK/gh-offline-once" ]]; then
    rm -f "$FAKE_WORK/gh-offline-once"
    echo "error connecting to api.github.com" >&2
    exit 1
  fi
  cat "$FAKE_WORK/codespaces.json"
elif [[ "$1 $2" == "codespace ssh" && "$*" == *--config* ]]; then
  for name in alpha-cs-x1 beta-cs-x2 epsilon-cs-x5; do
    printf 'Host cs.%s.main\n' "$name"
    printf '\tUser root\n'
    printf '\tProxyCommand /usr/bin/gh cs ssh -c %s --stdio -- -i /k/key\n' "$name"
    printf '\tIdentityFile /k/key\n\n'
  done
  # Like gh, report stopped Codespaces with a failing status.
  printf 'skipping unavailable codespace gamma-cs-x3: Shutdown\n' >&2
  exit 1
elif [[ "$1 $2" == "codespace view" ]]; then
  case "$*" in
    *alpha-cs-x1*) printf 'Available\n' ;;
    *) printf 'Shutdown\n' ;;
  esac
else
  printf 'unexpected gh call: %s\n' "$*" >&2
  exit 1
fi
FAKE_GH

cat >"$fake_bin/herdr" <<'FAKE_HERDR'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_HERDR_LOG"
case "$1 ${2:-}" in
  "machine list") cat "$FAKE_WORK/machines.json" ;;
  "machine add")
    [[ ! -t 0 ]] || { echo "stdin must not be a terminal" >&2; exit 3; }
    [[ "$3" != *epsilon* ]] || { echo "error: herdr not installed; machine was not saved" >&2; exit 1; }
    if [[ -n "${FAKE_SAVE_ADDS:-}" ]]; then
      # Connecting takes a while; then the machine is saved.
      sleep 1
      jq --arg target "$3" '. + [{id: ("ep_" + $target), label: "added", target: $target,
        session: "default", enabled: true, selected: false}]' \
        "$FAKE_WORK/machines.json" >"$FAKE_WORK/machines.json.new"
      mv "$FAKE_WORK/machines.json.new" "$FAKE_WORK/machines.json"
    fi
    ;;
  "machine enable"|"machine disable"|"machine remove") ;;
  "--session codespaces")
    # The window stays open until the background sync has logged
    # FAKE_WAIT_COUNT calls starting with FAKE_WAIT_FOR.
    [[ -z "${FAKE_BACKDATE:-}" ]] || touch -t 202001010000 "$FAKE_BACKDATE"
    [[ -z "${FAKE_GH_OFFLINE_ONCE:-}" ]] || touch "$FAKE_WORK/gh-offline-once"
    for _ in $(seq 1 100); do
      count=$(grep -c "^$FAKE_WAIT_FOR" "$FAKE_HERDR_LOG" || true)
      (( count >= FAKE_WAIT_COUNT )) && exit 0
      sleep 0.1
    done
    echo "the background sync did not run" >&2
    exit 4
    ;;
  *) echo "unexpected herdr call: $*" >&2; exit 1 ;;
esac
FAKE_HERDR
chmod +x "$fake_bin/gh" "$fake_bin/herdr"

run_sync() {
  HOME="$fake_home" XDG_CACHE_HOME="$work_dir/cache" \
    PATH="$fake_bin:/usr/bin:/bin" \
    FAKE_WORK="$work_dir" FAKE_GH_LOG="$gh_log" FAKE_HERDR_LOG="$herdr_log" \
    bash "$script" "$@"
}

mkdir -p "$work_dir/cache/herdr-codespaces/auto-disabled"
touch "$work_dir/cache/herdr-codespaces/auto-disabled/beta-cs-x2"
output=$(run_sync sync 2>&1)

grep -Fqx 'machine add herdr-cs.alpha-cs-x1 --label mattsleeps (alpha-cs) --remote-session default' \
  "$herdr_log" || fail "alpha was not added with its repository label"
grep -Fqx 'machine enable ep_beta' "$herdr_log" || fail "beta was not re-enabled"
grep -Fq 'ep_zeta' "$herdr_log" && fail "a machine disabled by the user was re-enabled"
[[ -f "$work_dir/cache/herdr-codespaces/auto-disabled/gamma-cs-x3" ]] \
  || fail "gamma was not recorded as disabled by sync"
[[ ! -e "$work_dir/cache/herdr-codespaces/auto-disabled/beta-cs-x2" ]] \
  || fail "beta's auto-disabled record was kept after re-enabling it"
grep -Fqx 'machine disable ep_gamma' "$herdr_log" || fail "stopped gamma was not disabled"
grep -Fqx 'machine remove ep_delta' "$herdr_log" || fail "deleted delta was not removed"
grep -Fq 'ep_mine' "$herdr_log" && fail "a machine not created by herdr-codespaces was changed"
grep -Fq 'could not connect vyta (epsilon-cs)' <<<"$output" \
  || fail "the failed epsilon connection was not reported"
grep -Fqx 'machine remove ep_eta_a' "$herdr_log" || fail "eta's duplicate machine was not removed"
grep -Fq 'ep_eta_b' "$herdr_log" && fail "eta's selected machine was changed"
grep -Fq 'machine add herdr-cs.eta' "$herdr_log" && fail "eta was added again"
[[ ! -e "$work_dir/cache/herdr-codespaces/sync.lock" ]] || fail "the sync lock was kept"

# The SSH aliases are stable per Codespace and connect through the guard that
# refuses to start stopped Codespaces.
hosts="$fake_home/.ssh/herdr-codespaces"
grep -Fqx 'Host herdr-cs.alpha-cs-x1' "$hosts" || fail "missing stable host alias"
grep -Fq "ProxyCommand \"$script\" proxy /usr/bin/gh cs ssh -c alpha-cs-x1 --stdio" "$hosts" \
  || fail "ProxyCommand is not routed through the guard"
# Herdr forces StrictHostKeyChecking=yes, so each host must list its key.
[[ "$(grep -c 'KnownHostsCommand /bin/echo %H %t %K' "$hosts")" == 3 ]] \
  || fail "a host alias does not accept the key of its gh tunnel"
[[ "$(stat -c %a "$hosts" 2>/dev/null || stat -f %Lp "$hosts")" == 600 ]] \
  || fail "host file is not private"

# Reruns keep one Include. A sync you run retries a failed Codespace at once:
# its bootstrap may have installed herdr since.
: >"$herdr_log"
run_sync sync >/dev/null 2>&1
[[ "$(grep -Fc 'Include ~/.ssh/herdr-codespaces' "$fake_home/.ssh/config")" == 1 ]] \
  || fail "Include was added more than once"
grep -Fq 'machine add herdr-cs.epsilon-cs-x5' "$herdr_log" \
  || fail "a sync you run did not retry the failed Codespace"

# The window's background sync skips it until the back-off has passed.
: >"$herdr_log"
FAKE_WAIT_FOR='machine list' FAKE_WAIT_COUNT=3 HERDR_CODESPACES_SYNC_SECONDS=0.1 \
  run_sync >/dev/null 2>&1 || fail "the window did not sync in the background"
[[ "$(grep -c 'machine add herdr-cs.epsilon-cs-x5' "$herdr_log")" == 1 ]] \
  || fail "the background sync retried a failed Codespace before the back-off"

# A failure marker older than the back-off is retried. Backdate it: BSD find
# treats a file touched in the current second as newer than -mmin -0.
: >"$herdr_log"
FAKE_BACKDATE="$work_dir/cache/herdr-codespaces/add-failed/epsilon-cs-x5" \
  FAKE_WAIT_FOR='machine add herdr-cs.epsilon-cs-x5' FAKE_WAIT_COUNT=2 \
  HERDR_CODESPACES_SYNC_SECONDS=0.1 run_sync >/dev/null 2>&1 \
  || fail "the background sync did not retry a failed Codespace after the back-off"

# A sync that dies (gh offline) does not end the window's background sync.
: >"$herdr_log"
FAKE_GH_OFFLINE_ONCE=1 FAKE_WAIT_FOR='machine list' FAKE_WAIT_COUNT=3 \
  HERDR_CODESPACES_SYNC_SECONDS=0.1 run_sync >/dev/null 2>&1 \
  || fail "the background sync stopped after a failed sync"
[[ ! -e "$work_dir/gh-offline-once" ]] || fail "the background sync did not run while gh was offline"

# Two syncs at once add a newly started Codespace only once.
cp "$work_dir/machines.json" "$work_dir/machines.orig.json"
: >"$herdr_log"
FAKE_SAVE_ADDS=1 run_sync sync >/dev/null 2>&1 &
first_sync=$!
FAKE_SAVE_ADDS=1 run_sync sync >/dev/null 2>&1 || fail "the second sync failed"
wait "$first_sync" || fail "the first sync failed"
[[ "$(grep -c 'machine add herdr-cs.alpha-cs-x1' "$herdr_log")" == 1 ]] \
  || fail "two syncs at once added a Codespace twice"
cp "$work_dir/machines.orig.json" "$work_dir/machines.json"

# The lock of a sync that died does not block the next one.
sh -c 'exit 0' &
dead_pid=$!
wait "$dead_pid" || true
mkdir "$work_dir/cache/herdr-codespaces/sync.lock"
printf '%s\n' "$dead_pid" >"$work_dir/cache/herdr-codespaces/sync.lock/pid"
output=$(run_sync sync 2>&1) || fail "a sync after a dead one failed: $output"
grep -Fq 'Waiting' <<<"$output" && fail "a sync waited for a dead sync's lock"

# A sync that found the dead lock reclaims it only while it still names the
# dead sync, and not while another sync reclaims it: the other sync may have
# removed it and locked again in between. Load the functions without main.
[[ "$(tail -n 1 "$script")" == 'main "$@"' ]] || fail "the script no longer ends with main"
sed '$d' "$script" >"$work_dir/functions.sh"
(
  HOME="$fake_home" XDG_CACHE_HOME="$work_dir/cache" PATH="$fake_bin:/usr/bin:/bin"
  # shellcheck source=/dev/null
  source "$work_dir/functions.sh"
  mkdir "$lock_dir"
  printf '%s\n' "$$" >"$lock_dir/pid"
  reclaim_lock "$dead_pid"
  [[ -d "$lock_dir" ]] || fail "reclaiming removed the lock another sync took"
  printf '%s\n' "$dead_pid" >"$lock_dir/pid"
  mkdir "$lock_dir.reclaim"
  reclaim_lock "$dead_pid" && fail "two syncs reclaimed the lock at once"
  [[ -d "$lock_dir" ]] || fail "a lock being reclaimed was removed twice"
  rmdir "$lock_dir.reclaim"
  reclaim_lock "$dead_pid" || fail "a dead sync's lock could not be reclaimed"
  [[ ! -e "$lock_dir" ]] || fail "a dead sync's lock was not removed"
)

# hide removes a Codespace's machines and keeps it out of the window. It takes
# the repository or the Codespace's name as the sidebar shows it.
hidden_dir="$work_dir/cache/herdr-codespaces/hidden"
: >"$herdr_log"
output=$(run_sync hide PAUW 2>&1) || fail "hide by repository failed: $output"
[[ -e "$hidden_dir/eta-cs-x7" ]] || fail "hide did not record eta"
grep -Fqx 'machine remove ep_eta_b' "$herdr_log" || fail "hide did not remove eta's machine"
grep -Fqx 'machine remove ep_eta_a' "$herdr_log" || fail "hide kept eta's duplicate"
run_sync hide alpha-cs >/dev/null 2>&1 || fail "hide by Codespace name failed"
[[ -e "$hidden_dir/alpha-cs-x1" ]] || fail "hide did not record alpha"
if run_sync hide nothing-here >/dev/null 2>&1; then
  fail "hide accepted a Codespace that does not exist"
fi
: >"$herdr_log"
run_sync sync >/dev/null 2>&1
grep -Fq 'machine add herdr-cs.alpha' "$herdr_log" && fail "a sync added a hidden Codespace"
[[ "$(run_sync show 2>&1)" == $'alpha-cs-x1\neta-cs-x7' ]] \
  || fail "show did not list the hidden Codespaces"

# show brings one back at once.
: >"$herdr_log"
run_sync show alpha-cs >/dev/null 2>&1 || fail "show failed"
[[ ! -e "$hidden_dir/alpha-cs-x1" ]] || fail "show kept alpha hidden"
grep -Fq 'machine add herdr-cs.alpha-cs-x1' "$herdr_log" || fail "show did not add alpha back"

# A hidden Codespace that was deleted is forgotten.
touch "$hidden_dir/delta-cs-x4"
run_sync sync >/dev/null 2>&1
[[ ! -e "$hidden_dir/delta-cs-x4" ]] || fail "a deleted Codespace stayed hidden"

# The guard only lets SSH through to an Available Codespace.
guard() {
  PATH="$fake_bin:/usr/bin:/bin" FAKE_GH_LOG="$gh_log" \
    bash "$script" proxy "$fake_bin/gh" "$@"
}
if guard cs ssh -c gamma-cs-x3 --stdio 2>/dev/null; then
  fail "guard started a stopped Codespace"
fi
: >"$gh_log"
guard codespace view -c alpha-cs-x1 --json state --jq .state >/dev/null
[[ "$(grep -c 'codespace view -c alpha-cs-x1' "$gh_log")" == 2 ]] \
  || fail "guard did not pass an Available Codespace through"

printf 'herdr-codespaces tests passed.\n'
