#!/usr/bin/env bash
# Wait for the test run that /run-tests started on each branch and report
# PASS/FAIL. /run-tests dispatches the test workflow on the PR's head branch
# (workflow_dispatch), so that run never shows up in `gh pr checks`; this
# follows it with `gh run` instead. Exits non-zero when any run failed or
# none appeared. Run it in the background; it can take as long as CI does.
#
# With --merge, once every run passed it also waits for each PR's own checks
# (pre-commit, commit message, version bump) and squash-merges the PRs in the
# order given. Nothing is merged unless everything passed. GitHub's auto-merge
# cannot do this: the 360ERP branches are unprotected and the /run-tests run is
# not a PR check.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: watch_ci.sh [--since UTC-TIMESTAMP] [--workflow FILE] [--merge] BRANCH...

  --since     Only runs created at or after this time, e.g. 2026-10-19T12:00:00Z
              (default: 15 minutes ago). ship.sh prints the right value.
  --workflow  Workflow file /run-tests dispatches (default: test.yml)
  --merge     When every run and every PR check passed, squash-merge each
              branch's open PR. Only when the user asked for the merge.
EOF
}

# GNU date, then BSD date (macOS).
since=$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u -v-15M +%Y-%m-%dT%H:%M:%SZ)
workflow=test.yml
merge=0
branches=()
while (($#)); do
  case $1 in
    --since) since=${2:?--since needs a timestamp}; shift 2 ;;
    --workflow) workflow=${2:?--workflow needs a file}; shift 2 ;;
    --merge) merge=1; shift ;;
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

if ((merge)); then
  if ((status)); then
    printf 'NOT MERGED: a test run failed or never started\n'
    exit "$status"
  fi
  # Resolve every PR and wait for all of their checks before merging any, so
  # a failure on the staging PR never leaves the feature PR merged alone.
  prs=()
  for branch in "${branches[@]}"; do
    pr=$(gh pr list --head "$branch" --state open --json url --jq '.[0].url // empty')
    if [[ -z $pr ]]; then
      printf 'NOT MERGED: %s has no open PR\n' "$branch"
      exit 1
    fi
    checks=$(gh pr checks "$pr" --watch --interval 30 2>&1) || {
      if grep -q 'no checks reported' <<<"$checks"; then
        printf 'CHECKS %s: none reported\n' "$pr"
      else
        printf 'NOT MERGED: checks failed on %s\n%s\n' "$pr" "$(tail -n 20 <<<"$checks")"
        exit 1
      fi
    }
    prs+=("$pr")
  done
  for pr in "${prs[@]}"; do
    if gh pr merge "$pr" --squash; then
      printf 'MERGED  %s\n' "$pr"
    else
      printf 'MERGE FAILED  %s\n' "$pr"
      status=1
    fi
  done
fi
exit "$status"
