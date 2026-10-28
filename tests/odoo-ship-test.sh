#!/usr/bin/env bash
# Exercises odoo-ship's ship.sh and watch_ci.sh against a local bare "origin"
# and a fake gh. The cases that matter: the first ship opens both PRs and
# resolves the staging manifest-version conflict, a rerun changes nothing, a
# follow-up commit reuses the staging branch, a newer commit that reuses a
# shipped message is still picked, a pick pushed from another Codespace is
# caught up instead of repeated, a diverged local staging branch is refused, a
# stale staging branch gets the next -N and skips commits a squash-merged
# staging PR already brought, a real conflict stops the run, --dry-run touches
# nothing, an already-merged feature branch is refused, and --no-staging opens
# only the feature PR. watch_ci.sh --merge squash-merges only when every test
# run and every PR check passed.

set -euo pipefail

repo_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ship_sh="$repo_dir/odoo-dev-skills/odoo-ship/scripts/ship.sh"
watch_sh="$repo_dir/odoo-dev-skills/odoo-ship/scripts/watch_ci.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

# In-place sed that works with both GNU and BSD (macOS) sed.
sed_i() { sed "$1" "$2" >"$2.tmp" && mv "$2.tmp" "$2"; }

# Isolate from the user's Git configuration (signing, hooks, conflict style).
export GIT_CONFIG_GLOBAL="$work/gitconfig" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
: >"$GIT_CONFIG_GLOBAL"

# --- Fake gh: records calls; open PRs are files named <base>..<head> ---------
state="$work/gh"
mkdir -p "$state/prs" "$work/bin"
printf '0\n' >"$state/counter"
cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state=$FAKE_GH_STATE
printf '%s\n' "$*" >>"$state/calls.log"
cmd="$1 $2"
shift 2
head="" base="" title="" body="" pr_state=open
args=("$@")
while (($#)); do
  case $1 in
    --state) pr_state=$2; shift 2 ;;
    --head) head=$2; shift 2 ;;
    --base) base=$2; shift 2 ;;
    --title) title=$2; shift 2 ;;
    --body-file) body=$2; shift 2 ;;
    *) shift ;;
  esac
done
case $cmd in
  "pr list")
    if [[ $pr_state == merged ]]; then
      cat "$state/merged-$base.json" 2>/dev/null || echo '[]'
    elif [[ -z $base ]]; then
      cat "$state"/prs/*.."$head" 2>/dev/null || true
    elif [[ -f "$state/prs/$base..$head" ]]; then
      cat "$state/prs/$base..$head"
    fi
    ;;
  "pr create")
    n=$(($(<"$state/counter") + 1))
    printf '%s\n' "$n" >"$state/counter"
    url="https://github.com/360ERP/Test/pull/$n"
    printf '%s\n' "$url" >"$state/prs/$base..$head"
    printf '%s\n' "$title" >"$state/pr-$n.title"
    cp "$body" "$state/pr-$n.body"
    printf 'Creating pull request for %s into %s\n\n%s\n' "$head" "$base" "$url"
    ;;
  "pr comment") printf '%s %s\n' "${args[0]}" "${args[2]}" >>"$state/comments.log" ;;
  "pr checks") echo "checks for ${args[0]}"; exit "$(cat "$state/checks-exit" 2>/dev/null || echo 0)" ;;
  "pr merge") printf '%s %s\n' "${args[0]}" "${args[1]}" >>"$state/merges.log" ;;
  "run list") printf '%s\n' "$(<"$state/run-id")" ;;
  "run view")
    if [[ " ${args[*]} " == *" --log-failed "* ]]; then echo "failed step log"; else echo "https://example.test/run"; fi
    ;;
  "run watch") exit "$(<"$state/run-exit")" ;;
  *) echo "fake gh: unsupported: $cmd" >&2; exit 1 ;;
esac
EOF
chmod +x "$work/bin/gh"
: >"$state/comments.log"

comments() { wc -l <"$state/comments.log" | tr -d ' '; }
prs_created() { cat "$state/counter"; }

# --- Origin with 18.0 and a staging branch whose version is ahead ------------
origin="$work/origin.git"
git init -q --bare "$origin"

seed="$work/seed"
git init -q -b 18.0 "$seed"
git -C "$seed" remote add origin "$origin"
set_version() {
  sed_i "s/\"version\": \"[^\"]*\"/\"version\": \"$2\"/" "$1/custom/mod_a/__manifest__.py"
}
mkdir -p "$seed/custom/mod_a"
cat >"$seed/custom/mod_a/__manifest__.py" <<'EOF'
{
    "name": "Module A",
    "version": "18.0.1.0.0",
    "depends": ["base"],
}
EOF
printf 'line one\nline two\nline three\n' >"$seed/custom/mod_a/models.py"
git -C "$seed" add -A
git -C "$seed" commit -q -m "[task-0000] mod_a:" -m "Initial module"
git -C "$seed" push -q origin 18.0
git -C "$seed" checkout -q -b 18.0-staging
set_version "$seed" 18.0.1.3.0
git -C "$seed" commit -q -am "[task-0000] mod_a:" -m "Staging moves ahead"
git -C "$seed" push -q origin 18.0-staging
git --git-dir="$origin" symbolic-ref HEAD refs/heads/18.0

# --- The working clone, whose origin looks like a 360ERP GitHub repo ---------
repo="$work/repo"
git clone -q "$origin" "$repo"
git -C "$repo" config remote.origin.url https://github.com/360ERP/Test.git
git -C "$repo" config url."$origin".insteadOf https://github.com/360ERP/Test.git
git -C "$repo" checkout -q -b 18.0-request-1 origin/18.0

ship() {
  (cd "$repo/custom" && PATH="$work/bin:$PATH" FAKE_GH_STATE="$state" bash "$ship_sh" "$@")
}
remote_file() { git --git-dir="$origin" show "$1:custom/mod_a/$2"; }
remote_version() { remote_file "$1" __manifest__.py | sed -n 's/.*"version": "\([^"]*\)".*/\1/p'; }
ahead_of_staging() { git --git-dir="$origin" rev-list --count "18.0-staging..$1"; }
feature_commit() { # sed expression, description, [new version]
  sed_i "$1" "$repo/custom/mod_a/models.py"
  [[ -z ${3:-} ]] || set_version "$repo" "$3"
  git -C "$repo" commit -q -am "[request-1] mod_a:" -m "$2"
}

# 0. Uncommitted changes to tracked files are refused.
printf 'dirty\n' >>"$repo/custom/mod_a/models.py"
if ship >/dev/null 2>&1; then fail 'ship.sh accepted uncommitted changes.'; fi
git -C "$repo" checkout -q -- custom/mod_a/models.py

# 1. First ship: both PRs, staging version conflict resolved, back on feature.
feature_commit 's/^line one$/line one feature/' 'Add feature one' 18.0.1.1.0
printf '## What\n\nFeature one.\n' >"$work/body.md"
out=$(ship --body-file "$work/body.md" 2>&1) || fail "First ship failed: $out"

[[ $(<"$state/pr-1.title") == '[request-1] mod_a: Add feature one' ]] \
  || fail "Feature PR title: $(<"$state/pr-1.title")"
[[ -f "$state/prs/18.0..18.0-request-1" ]] || fail 'Feature PR does not target 18.0.'
grep -qx 'https://github.com/360ERP/Test/pull/1 /run-tests' "$state/comments.log" \
  || fail 'No /run-tests on the feature PR.'
[[ $(remote_version 18.0-staging-request-1) == 18.0.1.4.0 ]] \
  || fail "Staging version is $(remote_version 18.0-staging-request-1), expected 18.0.1.4.0"
remote_file 18.0-staging-request-1 models.py | grep -qx 'line one feature' \
  || fail 'The feature change is missing on the staging branch.'
[[ -f "$state/prs/18.0-staging..18.0-staging-request-1" ]] \
  || fail 'Staging PR does not target 18.0-staging.'
[[ $(<"$state/pr-2.title") == '[request-1] mod_a: Add feature one (staging)' ]] \
  || fail "Staging PR title: $(<"$state/pr-2.title")"
[[ $(head -n 1 "$state/pr-2.body") == 'Staging counterpart of #1, cherry-picked onto `18.0-staging`.' ]] \
  || fail "Staging PR body starts with: $(head -n 1 "$state/pr-2.body")"
grep -q 'Feature one.' "$state/pr-2.body" || fail 'Staging PR body lost the description.'
grep -qx 'https://github.com/360ERP/Test/pull/2 /run-tests' "$state/comments.log" \
  || fail 'No /run-tests on the staging PR.'
[[ $(git -C "$repo" branch --show-current) == 18.0-request-1 ]] \
  || fail 'ship.sh did not return to the feature branch.'
grep -q 'watch_ci.sh --since .* 18.0-request-1 18.0-staging-request-1' <<<"$out" \
  || fail 'No watch_ci.sh line for both branches.'

# 2. A rerun pushes, creates, and comments nothing.
out=$(ship 2>&1) || fail "Rerun failed: $out"
[[ $(comments) == 2 && $(prs_created) == 2 ]] || fail 'Rerun commented or created a PR.'
[[ $(ahead_of_staging 18.0-staging-request-1) == 1 ]] || fail 'Rerun cherry-picked again.'

# 3. A follow-up commit reuses the current staging branch and its PR.
feature_commit 's/^line two$/line two feature/' 'Add feature two'
out=$(ship 2>&1) || fail "Follow-up ship failed: $out"
[[ $(prs_created) == 2 ]] || fail 'Follow-up ship created a new PR.'
[[ $(comments) == 4 ]] || fail "Follow-up ship posted $(comments) comments in total, expected 4."
[[ $(ahead_of_staging 18.0-staging-request-1) == 2 ]] \
  || fail 'Follow-up commit was not cherry-picked onto the reused staging branch.'

# 3b. A newer commit that reuses a shipped commit's message is still picked.
printf 'line five\n' >>"$repo/custom/mod_a/models.py"
git -C "$repo" commit -q -am "[request-1] mod_a:" -m "Add feature two"
out=$(ship 2>&1) || fail "Ship of a repeated message failed: $out"
[[ $(ahead_of_staging 18.0-staging-request-1) == 3 ]] \
  || fail 'A commit that reuses a shipped message was not cherry-picked.'
remote_file 18.0-staging-request-1 models.py | grep -qx 'line five' \
  || fail 'The repeated-message change is missing on staging.'

# 3c. When another Codespace already pushed the pick, the stale local staging
#     branch catches up instead of picking it again.
printf 'line six\n' >>"$repo/custom/mod_a/models.py"
git -C "$repo" commit -q -am "[request-1] mod_a:" -m "Add feature six"
other="$work/other"
git clone -q "$origin" "$other"
git -C "$other" checkout -q 18.0-staging-request-1
git -C "$other" fetch -q "$repo" 18.0-request-1
# Its own committer date, as a pick made elsewhere would have; otherwise the
# pick below could produce the very same commit.
GIT_COMMITTER_DATE='2001-02-03T04:05:06Z' git -C "$other" cherry-pick FETCH_HEAD >/dev/null
git -C "$other" push -q origin 18.0-staging-request-1
comments_before=$(comments)
out=$(ship 2>&1) || fail "Ship after a push from elsewhere failed: $out"
[[ $(ahead_of_staging 18.0-staging-request-1) == 4 ]] \
  || fail 'The pick pushed from elsewhere was picked again.'
[[ $(git -C "$repo" rev-parse 18.0-staging-request-1) \
  == $(git --git-dir="$origin" rev-parse 18.0-staging-request-1) ]] \
  || fail 'The local staging branch did not catch up with origin.'
[[ $(comments) == $((comments_before + 1)) ]] \
  || fail 'Expected /run-tests on the feature PR only; staging was unchanged.'

# 3d. A local staging branch that has diverged from origin is refused.
git -C "$repo" checkout -q 18.0-staging-request-1
printf 'local\n' >"$repo/custom/mod_a/LOCAL"
git -C "$repo" add custom/mod_a/LOCAL
git -C "$repo" commit -q -m "[request-1] mod_a:" -m "Local only"
git -C "$repo" checkout -q 18.0-request-1
printf 'remote\n' >"$other/custom/mod_a/REMOTE"
git -C "$other" add custom/mod_a/REMOTE
git -C "$other" commit -q -m "[request-1] mod_a:" -m "Remote only"
git -C "$other" push -q origin 18.0-staging-request-1
if out=$(ship 2>&1); then fail 'Shipped onto a diverged staging branch.'; fi
grep -q 'local 18.0-staging-request-1 and origin/18.0-staging-request-1 have diverged' <<<"$out" \
  || fail "Unexpected stop: $out"
git -C "$repo" branch -q -f 18.0-staging-request-1 origin/18.0-staging-request-1

# 4. After the staging PR is squash-merged, the next ship creates -2 and picks
#    only the commit staging does not have yet.
git -C "$seed" fetch -q origin
git -C "$seed" merge -q --squash origin/18.0-staging-request-1 >/dev/null
git -C "$seed" commit -q -m '[request-1] mod_a: (#2)' -m '* Add feature one, two, six'
git -C "$seed" push -q origin 18.0-staging
rm "$state/prs/18.0-staging..18.0-staging-request-1"
cat >"$state/merged-18.0-staging.json" <<'EOF'
[{"headRefName": "18.0-staging-request-1", "url": "https://github.com/360ERP/Test/pull/2",
  "commits": [{"messageHeadline": "[request-1] mod_a:", "messageBody": "Add feature one"},
              {"messageHeadline": "[request-1] mod_a:", "messageBody": "Add feature two"},
              {"messageHeadline": "[request-1] mod_a:", "messageBody": "Add feature two"},
              {"messageHeadline": "[request-1] mod_a:", "messageBody": "Add feature six"}]}]
EOF
feature_commit 's/^line three$/line three feature/' 'Add feature three' 18.0.1.2.0
out=$(ship 2>&1) || fail "Ship after merge failed: $out"
grep -q '18.0-staging-request-1 is stale' <<<"$out" || fail 'Stale branch was not reported.'
[[ $(ahead_of_staging 18.0-staging-request-1-2) == 1 ]] \
  || fail "-2 has $(ahead_of_staging 18.0-staging-request-1-2) commits over staging, expected 1."
[[ $(remote_version 18.0-staging-request-1-2) == 18.0.1.5.0 ]] \
  || fail "-2 version is $(remote_version 18.0-staging-request-1-2), expected 18.0.1.5.0"
[[ $(<"$state/pr-3.title") == '[request-1] mod_a: Add feature three (staging)' ]] \
  || fail 'No staging PR for the -2 branch.'

# 5. --dry-run changes nothing; a real conflict stops on the staging branch.
sed_i 's/^line three$/line three staging/' "$seed/custom/mod_a/models.py"
git -C "$seed" commit -q -am "[task-0000] mod_a:" -m "Staging edits line three"
git -C "$seed" push -q origin 18.0-staging
calls_before=$(wc -l <"$state/calls.log")
out=$(ship --dry-run 2>&1) || fail "Dry run failed: $out"
grep -q '18.0-staging-request-1-3 (new; 18.0-staging-request-1-2 is stale' <<<"$out" \
  || fail "Dry run plan is wrong: $out"
grep -v '^pr list' <(tail -n +"$((calls_before + 1))" "$state/calls.log") | grep -q . \
  && fail 'Dry run called gh for more than listing PRs.'
git -C "$repo" show-ref -q --verify refs/heads/18.0-staging-request-1-3 \
  && fail 'Dry run created the staging branch.'
if out=$(ship 2>&1); then fail 'A real conflict did not stop ship.sh.'; fi
grep -q 'conflicts in:.*custom/mod_a/models.py' <<<"$out" || fail "Unexpected stop: $out"
[[ $(git -C "$repo" branch --show-current) == 18.0-staging-request-1-3 ]] \
  || fail 'ship.sh did not stop on the staging branch.'
git -C "$repo" cherry-pick --abort
git -C "$repo" checkout -q 18.0-request-1

# 6. Once the feature PR is squash-merged, the branch has nothing left for
#    18.0, and newer commits on it are sent to a fresh -2 branch.
git -C "$seed" fetch -q origin
git -C "$seed" checkout -q 18.0
git -C "$seed" merge -q --squash origin/18.0-request-1 >/dev/null
git -C "$seed" commit -q -m '[request-1] mod_a: (#1)' -m 'Squashed'
git -C "$seed" push -q origin 18.0 :18.0-request-1
rm "$state/prs/18.0..18.0-request-1"
cat >"$state/merged-18.0.json" <<'EOF'
[{"headRefName": "18.0-request-1", "url": "https://github.com/360ERP/Test/pull/1",
  "commits": [{"messageHeadline": "[request-1] mod_a:", "messageBody": "Add feature one"},
              {"messageHeadline": "[request-1] mod_a:", "messageBody": "Add feature two"},
              {"messageHeadline": "[request-1] mod_a:", "messageBody": "Add feature two"},
              {"messageHeadline": "[request-1] mod_a:", "messageBody": "Add feature six"},
              {"messageHeadline": "[request-1] mod_a:", "messageBody": "Add feature three"}]}]
EOF
if out=$(ship --no-staging 2>&1); then fail 'Shipped an already-merged branch.'; fi
grep -q 'already merged into 18.0 as https://github.com/360ERP/Test/pull/1' <<<"$out" \
  || fail "Unexpected refusal: $out"
feature_commit 's/^line two feature$/line two final/' 'Add feature four'
if out=$(ship 2>&1); then fail 'Shipped new commits on an already-merged branch.'; fi
grep -q 'git checkout -b 18.0-request-1-2 origin/18.0' <<<"$out" \
  || fail "No fresh-branch instruction: $out"

# 7. --no-staging opens only the feature PR.
git -C "$repo" checkout -q -b 18.0-task-7 origin/18.0
printf 'line four\n' >>"$repo/custom/mod_a/models.py"
git -C "$repo" commit -q -am "[task-7] mod_a:" -m "Small fix"
out=$(ship --no-staging 2>&1) || fail "--no-staging ship failed: $out"
[[ -f "$state/prs/18.0..18.0-task-7" ]] || fail '--no-staging did not open the feature PR.'
[[ -z $(git --git-dir="$origin" branch --list '18.0-staging-task-7*') ]] \
  || fail '--no-staging created a staging branch.'

# 8. watch_ci.sh reports the dispatched run's result.
watch() { PATH="$work/bin:$PATH" FAKE_GH_STATE="$state" bash "$watch_sh" "$@"; }
printf '123\n' >"$state/run-id"
printf '0\n' >"$state/run-exit"
out=$(watch 18.0-request-1) || fail "watch_ci.sh failed on a passing run: $out"
grep -q '^PASS  18.0-request-1' <<<"$out" || fail "No PASS line: $out"
printf '1\n' >"$state/run-exit"
if out=$(watch 18.0-request-1); then fail 'watch_ci.sh succeeded on a failing run.'; fi
grep -q '^FAIL  18.0-request-1' <<<"$out" || fail "No FAIL line: $out"
grep -q 'failed step log' <<<"$out" || fail 'The failed log was not shown.'

# 9. watch_ci.sh --merge squash-merges every PR only when everything passed.
merges() { wc -l <"$state/merges.log" | tr -d ' '; }
: >"$state/merges.log"
if out=$(watch --merge 18.0-task-7); then fail 'watch_ci.sh --merge succeeded on a failing run.'; fi
grep -q '^NOT MERGED' <<<"$out" || fail "No NOT MERGED line: $out"
[[ $(merges) == 0 ]] || fail 'Merged after a failing test run.'
printf '0\n' >"$state/run-exit"
printf '1\n' >"$state/checks-exit"
if out=$(watch --merge 18.0-task-7); then fail 'watch_ci.sh --merge succeeded on failing PR checks.'; fi
grep -q '^NOT MERGED: checks failed' <<<"$out" || fail "No failed-checks line: $out"
[[ $(merges) == 0 ]] || fail 'Merged after failing PR checks.'
printf '0\n' >"$state/checks-exit"
if out=$(watch --merge 18.0-no-pr); then fail 'watch_ci.sh --merge succeeded without a PR.'; fi
grep -q '^NOT MERGED: 18.0-no-pr has no open PR' <<<"$out" || fail "No missing-PR line: $out"
out=$(watch --merge 18.0-task-7) || fail "watch_ci.sh --merge failed on a passing run: $out"
grep -qx 'MERGED  https://github.com/360ERP/Test/pull/[0-9]*' <<<"$out" || fail "No MERGED line: $out"
grep -qx 'https://github.com/360ERP/Test/pull/[0-9]* --squash' "$state/merges.log" \
  || fail "Not a squash merge: $(cat "$state/merges.log")"

# 10. ship.sh --merge hands --merge to the printed watcher.
git -C "$repo" checkout -q -b 18.0-task-8 origin/18.0
printf 'line eight\n' >>"$repo/custom/mod_a/models.py"
git -C "$repo" commit -q -am "[task-8] mod_a:" -m "Merge me"
out=$(ship --no-staging --merge 2>&1) || fail "ship --merge failed: $out"
grep -q 'watch_ci.sh --since [^ ]* --merge 18.0-task-8$' <<<"$out" \
  || fail "The watcher line lacks --merge: $out"
[[ $(merges) == 1 ]] || fail 'ship.sh merged by itself.'

printf 'odoo-ship tests passed.\n'
