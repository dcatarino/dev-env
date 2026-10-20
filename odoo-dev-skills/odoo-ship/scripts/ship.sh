#!/usr/bin/env bash
# Ship a committed Odoo feature branch in a 360ERP repository:
#   1. push it and open (or reuse) its PR to the Odoo version branch;
#   2. reuse the current staging branch, or create the next -N one when it is
#      stale, and cherry-pick the feature commits staging does not have yet
#      (squash-merged ones are recognised through their PRs), resolving the
#      expected manifest-version conflict;
#   3. push it and open (or reuse) its PR to <version>-staging;
#   4. post one /run-tests comment on each PR that was created or whose branch
#      the push updated.
# Safe to rerun: commits already on the staging branch are skipped and an
# unchanged branch gets no new /run-tests comment. See ../SKILL.md.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
lib="$script_dir/ship_lib.py"

usage() {
  cat <<'EOF'
Usage: ship.sh [--body-file FILE] [--title TEXT] [--no-staging] [--dry-run]

Run inside a 360ERP repository with the change committed on its feature
branch (e.g. 18.0-request-1234). The identifier comes from the latest commit.

  --body-file FILE  Description for a new PR (default: the commit body)
  --title TEXT      PR title (default: commit subject + first body line);
                    the staging PR gets the same title plus " (staging)"
  --no-staging      Only the feature PR (e.g. 360_integrations)
  --dry-run         Print the plan; push, create, and comment nothing
EOF
}

die() { printf 'ship: %s\n' "$*" >&2; exit 1; }
step() { printf '\n== %s\n' "$*"; }

body_file="" title="" no_staging=0 dry_run=0
while (($#)); do
  case $1 in
    --body-file) body_file=${2:?--body-file needs a file}; shift 2 ;;
    --title) title=${2:?--title needs text}; shift 2 ;;
    --no-staging) no_staging=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done
if [[ -n $body_file ]]; then
  [[ -f $body_file ]] || die "body file not found: $body_file"
  body_file=$(cd "$(dirname "$body_file")" && pwd)/$(basename "$body_file")
fi

# --- Preconditions -----------------------------------------------------------

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a Git repository"
cd "$(git rev-parse --show-toplevel)"
origin_url=$(git config --get remote.origin.url) || die "no origin remote"
[[ $origin_url =~ github\.com[:/]360ERP/ ]] \
  || die "origin is not a 360ERP repository ($origin_url); see the odoo-pr skill"

feature=$(git branch --show-current)
[[ -n $feature ]] || die "detached HEAD; check out the feature branch"
[[ $feature =~ ^([0-9]+\.[0-9]+)- ]] \
  || die "branch '$feature' does not start with an Odoo version, e.g. 18.0-request-1234"
version=${BASH_REMATCH[1]}
[[ $feature != "$version-staging"* ]] \
  || die "'$feature' is a staging branch; check out the feature branch"
[[ -z $(git status --porcelain --untracked-files=no --ignore-submodules=all) ]] \
  || die "uncommitted changes to tracked files; commit them first (odoo-commit skill)"

# Title, description, and identifier come from the latest non-merge commit, so
# a "Merge 18.0 into ..." commit on top does not become the PR title.
subject=$(git log -1 --no-merges --format=%s)
[[ $subject =~ ^\[((ticket|task|request)-[0-9]+)\] ]] \
  || die "the latest commit's subject has no [ticket|task|request-N] identifier: $subject"
id=${BASH_REMATCH[1]}
description=$(git log -1 --no-merges --format=%b | sed -n '/[^[:space:]]/{p;q;}')
[[ -n $title ]] || title=$subject${description:+ $description}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
if [[ -z $body_file ]]; then
  body_file=$tmp_dir/body.md
  git log -1 --no-merges --format=%b >"$body_file"
fi
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)

git fetch -q origin "$version"
(($(git rev-list --count "origin/$version..HEAD") > 0)) \
  || die "nothing to ship: HEAD is already on origin/$version"
if ((!no_staging)); then
  [[ -n $(git ls-remote --heads origin "refs/heads/$version-staging") ]] \
    || die "origin has no $version-staging branch; use --no-staging"
  git fetch -q origin "$version-staging"
fi

# --- Plan (read-only) --------------------------------------------------------

remote_sha() { git ls-remote --heads origin "refs/heads/$1" | cut -f1; }
open_pr() {
  gh pr list --head "$1" --base "$2" --state open --json url --jq '.[0].url // empty'
}
first_body_line() { git log -1 --format=%b "$1" | sed -n '/[^[:space:]]/{p;q;}'; }
# PRs are squash-merged, which rewrites their commits: what was already merged
# is known from the merged PRs' original commit messages. `head:` matches a
# branch-name prefix, so this also finds the -N iterations.
merged_prs() {
  gh pr list --base "$1" --state merged --search "head:$2" --limit 30 \
    --json headRefName,url,commits >"$3"
}

feature_pr=$(open_pr "$feature" "$version")
feature_push=needed
[[ $(remote_sha "$feature") != "$(git rev-parse HEAD)" ]] || feature_push="up to date"

mapfile -t feature_commits < <(git rev-list --reverse --no-merges "origin/$version..$feature")
merged_prs "$version" "$feature" "$tmp_dir/merged-feature.json"
python3 "$lib" unshipped "origin/$version" --prs "$tmp_dir/merged-feature.json" \
  --branch "$feature" -- "${feature_commits[@]}" >"$tmp_dir/feature-new" \
  || die "could not compare $feature with its merged PRs"
mapfile -t feature_new <"$tmp_dir/feature-new"
feature_merged=$((${#feature_commits[@]} - ${#feature_new[@]}))
if ((feature_merged)); then
  merged_url=$(python3 "$lib" merged-url "$tmp_dir/merged-feature.json" "$feature")
  if ((${#feature_new[@]})); then
    if [[ $feature =~ ^(.*-(ticket|task|request)-[0-9]+)-([0-9]+)$ ]]; then
      next=${BASH_REMATCH[1]}-$((BASH_REMATCH[3] + 1))
    else
      next=$feature-2
    fi
    die "$feature was already merged into $version as $merged_url; put its newer commits on a fresh branch:
  git checkout -b $next origin/$version && git cherry-pick $(git rev-parse --short "${feature_new[@]}" | tr '\n' ' ')"
  fi
  ((!no_staging)) || die "nothing to ship: $feature was already merged into $version as $merged_url"
  feature_pr=$merged_url feature_push="skipped: already merged"
fi

staging="" staging_ref="" staging_state="" to_pick=()
if ((!no_staging)); then
  # Highest existing iteration of this identifier's staging branch, local or
  # remote: <version>-staging-<id> counts as 1, then -2, -3, ...
  base_name=$version-staging-$id
  highest="" highest_n=0
  while IFS= read -r branch; do
    if [[ $branch == "$base_name" ]]; then
      n=1
    elif [[ $branch == "$base_name"-* && ${branch#"$base_name"-} =~ ^[0-9]+$ ]]; then
      n=$((10#${branch#"$base_name"-}))
    else
      continue
    fi
    if ((n > highest_n)); then highest_n=$n highest=$branch; fi
  done < <(
    git for-each-ref --format='%(refname:short)' \
      "refs/heads/$base_name" "refs/heads/$base_name-*"
    git ls-remote --heads origin "$base_name" "$base_name-*" | sed 's|.*refs/heads/||'
  )

  if [[ -z $highest ]]; then
    staging=$base_name staging_ref=origin/$version-staging staging_state=new
  else
    # Use whichever of the local and the remote branch is ahead: another
    # Codespace may have pushed to it.
    highest_ref=""
    if [[ -n $(remote_sha "$highest") ]]; then
      git fetch -q origin "$highest"
      highest_ref=refs/remotes/origin/$highest
    fi
    if git show-ref --verify -q "refs/heads/$highest"; then
      if [[ -z $highest_ref ]] \
        || git merge-base --is-ancestor "$highest_ref" "refs/heads/$highest"; then
        highest_ref=refs/heads/$highest
      elif ! git merge-base --is-ancestor "refs/heads/$highest" "$highest_ref"; then
        die "local $highest and origin/$highest have diverged; reconcile them, then rerun"
      fi
    fi
    # Stale = upstream staging moved past what the branch was built on.
    if git merge-base --is-ancestor "origin/$version-staging" "$highest_ref"; then
      staging=$highest staging_ref=$highest_ref staging_state=reused
    else
      staging=$base_name-$((highest_n + 1)) staging_ref=origin/$version-staging
      staging_state="new; $highest is stale (origin/$version-staging moved on)"
    fi
  fi

  merged_prs "$version-staging" "$base_name" "$tmp_dir/merged-staging.json"
  python3 "$lib" unshipped "$staging_ref" --prs "$tmp_dir/merged-staging.json" \
    --branch "$base_name" --iterations -- "${feature_commits[@]}" >"$tmp_dir/to-pick" \
    || die "could not compare $feature with $staging_ref"
  mapfile -t to_pick <"$tmp_dir/to-pick"
fi

step "Plan for [$id] on $feature"
printf 'Title:       %s\n' "$title"
printf 'Feature PR:  %s (push %s)\n' "${feature_pr:-new PR to $version}" "$feature_push"
if ((!no_staging)); then
  printf 'Staging:     %s (%s)\n' "$staging" "$staging_state"
  printf 'To pick:     %s commit(s)\n' "${#to_pick[@]}"
  for sha in ${to_pick[@]+"${to_pick[@]}"}; do
    printf '             %s %s\n' "$(git rev-parse --short "$sha")" "$(first_body_line "$sha")"
  done
fi
if ((dry_run)); then
  printf '\nDry run: nothing pushed, created, or commented.\n'
  exit 0
fi

# --- Ship --------------------------------------------------------------------

# Push $1; set $pushed to "updated" when the push moved the remote branch.
push_branch() {
  if [[ $(remote_sha "$1") == "$(git rev-parse "refs/heads/$1")" ]]; then
    pushed=unchanged
    printf '%s: origin is already up to date\n' "$1"
  else
    git push -u origin "$1"
    pushed=updated
  fi
}

# Find or create the PR of branch $1 into $2; comment /run-tests when it was
# created or the last push updated its branch. Sets $pr_url and $pr_note.
ensure_pr() {
  local created=0
  pr_url=$(open_pr "$1" "$2")
  if [[ -z $pr_url ]]; then
    pr_url=$(gh pr create --base "$2" --head "$1" --title "$3" --body-file "$4" | tail -n 1)
    [[ $pr_url == http* ]] || die "gh pr create returned no PR URL: $pr_url"
    created=1
  fi
  if ((created)) || [[ $pushed == updated ]]; then
    gh pr comment "$pr_url" --body "/run-tests"
    pr_note="/run-tests posted"
    watch+=("$1")
  else
    pr_note="branch unchanged, no new /run-tests"
  fi
}

stop_conflict() {
  local sha=$1
  shift
  die "stopped on $staging: cherry-picking $(git rev-parse --short "$sha") conflicts in: $*
Resolve them, run 'git cherry-pick --continue', then rerun ship.sh; it skips commits already on $staging."
}

watch=()
if ((feature_merged)); then
  feature_note="already merged"
else
  step "Feature branch $feature -> $version"
  push_branch "$feature"
  ensure_pr "$feature" "$version" "$title" "$body_file"
  feature_pr=$pr_url feature_note=$pr_note
fi

staging_pr="" staging_note=""
if ((!no_staging)); then
  step "Staging branch $staging -> $version-staging"
  if [[ $staging_state != reused && ${#to_pick[@]} -eq 0 ]]; then
    staging_note="nothing to cherry-pick: $version-staging already has every feature commit"
    printf '%s\n' "$staging_note"
  else
    if [[ $staging_state == reused ]]; then
      if git show-ref --verify -q "refs/heads/$staging"; then
        git checkout -q "$staging"
        # Catch up with what was pushed from elsewhere (a fast-forward).
        [[ $staging_ref == refs/heads/* ]] || git merge -q --ff-only "$staging_ref"
      else
        git checkout -q -b "$staging" "$staging_ref"
      fi
    else
      git checkout -q -b "$staging" "origin/$version-staging"
    fi

    for sha in ${to_pick[@]+"${to_pick[@]}"}; do
      git -c merge.conflictStyle=merge cherry-pick "$sha" && continue
      mapfile -t conflicted < <(git diff --name-only --diff-filter=U)
      ((${#conflicted[@]})) \
        || die "cherry-pick of $(git rev-parse --short "$sha") stopped without a conflict (already on $staging? then 'git cherry-pick --skip')"
      for file in "${conflicted[@]}"; do
        [[ ${file##*/} == __manifest__.py ]] || stop_conflict "$sha" "${conflicted[@]}"
      done
      for file in "${conflicted[@]}"; do
        new_version=$(python3 "$lib" resolve-manifest "$file" "$sha") \
          || stop_conflict "$sha" "${conflicted[@]}"
        git add -- "$file"
        printf '%s: version conflict resolved to %s\n' "$file" "$new_version"
      done
      GIT_EDITOR=true git cherry-pick --continue
    done

    staging_body=$tmp_dir/staging-body.md
    {
      printf 'Staging counterpart of #%s, cherry-picked onto `%s-staging`.\n\n' \
        "${feature_pr##*/}" "$version"
      cat "$body_file"
    } >"$staging_body"
    push_branch "$staging"
    ensure_pr "$staging" "$version-staging" "$title (staging)" "$staging_body"
    staging_pr=$pr_url staging_note=$pr_note
    git checkout -q "$feature"
  fi
fi

step "Done"
printf 'Feature PR:  %s (%s)\n' "$feature_pr" "$feature_note"
if ((!no_staging)); then
  printf 'Staging PR:  %s (%s)\n' "${staging_pr:-none}" "$staging_note"
  [[ -z $staging_pr ]] || printf 'Staging:     %s (%s)\n' "$staging" "$staging_state"
fi
if ((${#watch[@]})); then
  printf 'Watch CI:    bash %s/watch_ci.sh --since %s %s\n' "$script_dir" "$started" "${watch[*]}"
fi
