#!/usr/bin/env bash
# Wait for the test run that /run-tests started on each branch and report
# PASS/FAIL. /run-tests dispatches the test workflow on the PR's head branch
# (workflow_dispatch), so that run never shows up in `gh pr checks`; this
# follows it with `gh run` instead. Exits non-zero when any run failed or
# none appeared. Run it in the background; it can take as long as CI does.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: watch_ci.sh [--since UTC-TIMESTAMP] [--workflow FILE] BRANCH...

  --since     Only runs created at or after this time, e.g. 2026-10-19T12:00:00Z
              (default: 15 minutes ago). ship.sh prints the right value.
  --workflow  Workflow file /run-tests dispatches (default: test.yml)
EOF
}

since=$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
workflow=test.yml
branches=()
while (($#)); do
  case $1 in
    --since) since=${2:?--since needs a timestamp}; shift 2 ;;
    --workflow) workflow=${2:?--workflow needs a file}; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    -*) usage >&2; exit 64 ;;
    *) branches+=("$1"); shift ;;
  esac
done
((${#branches[@]})) || { usage >&2; exit 64; }

status=0
for branch in "${branches[@]}"; do
  run_id=""
  # The comment listener needs a moment to dispatch the run.
  for _ in $(seq 40); do
    run_id=$(gh run list --workflow "$workflow" --branch "$branch" \
      --event workflow_dispatch --limit 5 --json databaseId,createdAt \
      --jq "[.[] | select(.createdAt >= \"$since\")] | sort_by(.createdAt) | last | .databaseId // empty")
    [[ -z $run_id ]] || break
    sleep 15
  done
  if [[ -z $run_id ]]; then
    printf 'NONE  %s: no %s run since %s\n' "$branch" "$workflow" "$since"
    status=1
    continue
  fi

  url=$(gh run view "$run_id" --json url --jq .url)
  if gh run watch "$run_id" --exit-status --interval 30 >/dev/null 2>&1; then
    printf 'PASS  %s  %s\n' "$branch" "$url"
  else
    printf 'FAIL  %s  %s\n' "$branch" "$url"
    gh run view "$run_id" --log-failed 2>/dev/null | tail -n 60 || true
    status=1
  fi
done
exit "$status"
