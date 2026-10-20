#!/usr/bin/env python3
"""Helpers for ship.sh.

resolve-manifest PATH SHA
    Resolve a cherry-pick conflict in PATH that touches only the manifest
    `version` line. Keeps the checked-out (staging) side and bumps its version
    at the level commit SHA bumped, e.g. staging 18.0.2.10.0 + a minor bump ->
    18.0.2.11.0. Prints the new version. Exits 2 when the conflict is anything
    else, leaving the file untouched.

unshipped REF [--prs JSON --branch BRANCH [--iterations]] -- SHA...
    Print, in order, the SHAs not yet shipped to REF. A commit counts as
    shipped when REF's history, or a merged PR in JSON (`gh pr list --json
    headRefName,url,commits`) whose head is BRANCH (with --iterations also
    BRANCH-<n>), has a commit with the same message. Squash merges keep the
    original messages only in the PR. Messages are compared with whitespace
    normalized, and each shipped occurrence accounts for one SHA, oldest
    first, so a newer commit that reuses a message is still unshipped.

merged-url JSON BRANCH
    Print the URL of the first merged PR in JSON whose head is BRANCH.
"""
import json
from collections import Counter
import re
import subprocess
import sys

VERSION_LINE = re.compile(r"""^(\s*["']version["']\s*:\s*["'])([^"']+)(["'].*)$""")


def git(*args):
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True
    ).stdout


def manifest_version(text):
    for line in text.splitlines():
        match = VERSION_LINE.match(line)
        if match:
            return match.group(2)
    return None


def bump_level(sha, path):
    """Index of the first version component SHA changed in PATH, or None."""
    try:
        before = manifest_version(git("show", f"{sha}^:{path}"))
        after = manifest_version(git("show", f"{sha}:{path}"))
    except subprocess.CalledProcessError:
        return None
    if not before or not after:
        return None
    old, new = before.split("."), after.split(".")
    if len(old) != len(new):
        return None
    for index, (a, b) in enumerate(zip(old, new)):
        if a != b:
            return index
    return None


def bumped(version, level):
    parts = version.split(".")
    parts[level] = str(int(parts[level]) + 1)
    parts[level + 1 :] = ["0"] * (len(parts) - level - 1)
    return ".".join(parts)


def version_lines(lines):
    return [i for i, line in enumerate(lines) if VERSION_LINE.match(line.rstrip("\r\n"))]


def resolve_manifest(path, sha):
    level = bump_level(sha, path)
    if level is None:
        return 2
    with open(path) as handle:
        lines = handle.read().splitlines(keepends=True)

    out, new_version, i = [], None, 0
    while i < len(lines):
        if not lines[i].startswith("<<<<<<< "):
            out.append(lines[i])
            i += 1
            continue
        j = i + 1
        while j < len(lines) and not lines[j].startswith("======="):
            j += 1
        k = j + 1
        while k < len(lines) and not lines[k].startswith(">>>>>>> "):
            k += 1
        if k >= len(lines):
            return 2
        ours, theirs = lines[i + 1 : j], lines[j + 1 : k]
        ours_v, theirs_v = version_lines(ours), version_lines(theirs)
        if len(ours_v) != 1 or len(theirs_v) != 1:
            return 2
        rest = lambda side, skip: [l for n, l in enumerate(side) if n != skip]
        if rest(ours, ours_v[0]) != rest(theirs, theirs_v[0]):
            return 2
        line = ours[ours_v[0]]
        ending = line[len(line.rstrip("\r\n")) :]
        match = VERSION_LINE.match(line.rstrip("\r\n"))
        try:
            new_version = bumped(match.group(2), level)
        except (ValueError, IndexError):
            return 2
        ours[ours_v[0]] = match.group(1) + new_version + match.group(3) + ending
        out.extend(ours)
        i = k + 1

    if new_version is None:
        return 2
    with open(path, "w") as handle:
        handle.writelines(out)
    print(new_version)
    return 0


def normalize(message):
    return " ".join(message.split())


def matching_prs(json_path, branch, iterations=False):
    pattern = re.escape(branch) + (r"(-[0-9]+)?" if iterations else "")
    with open(json_path) as handle:
        prs = json.load(handle)
    return [pr for pr in prs if re.fullmatch(pattern, pr.get("headRefName", ""))]


def pr_commit_message(commit):
    head, body = commit.get("messageHeadline", ""), commit.get("messageBody", "")
    if head.endswith("\u2026") and body.startswith("\u2026"):  # GitHub split a long subject
        return normalize(head[:-1] + body[1:])
    return normalize(head + "\n\n" + body)


def merged_url(json_path, branch):
    prs = matching_prs(json_path, branch)
    if prs:
        print(prs[0].get("url", ""))
    return 0


def log_messages(*args):
    """(sha, normalized message) pairs from `git log ARGS`."""
    out = git("log", "--format=%H%x1f%B%x1e", *args)
    pairs = (entry.strip().split("\x1f", 1) for entry in out.split("\x1e"))
    return [(sha, normalize(body)) for sha, body in (p for p in pairs if len(p) == 2)]


def unshipped(argv):
    if not argv or "--" not in argv:
        return 64
    ref, options, shas = argv[0], argv[1 : argv.index("--")], argv[argv.index("--") + 1 :]
    history = log_messages("-n", "5000", ref)
    shipped = Counter(message for _, message in history)
    if "--prs" in options:
        in_history = {sha for sha, _ in history}
        prs = matching_prs(
            options[options.index("--prs") + 1],
            options[options.index("--branch") + 1],
            "--iterations" in options,
        )
        # A PR merged with a merge commit is already in REF's history.
        for pr in prs:
            for commit in pr.get("commits", []):
                if commit.get("oid") not in in_history:
                    shipped[pr_commit_message(commit)] += 1
    if shas:
        for sha, message in log_messages("--no-walk=unsorted", *shas):
            if shipped[message]:
                shipped[message] -= 1
            else:
                print(sha)
    return 0


def main(argv):
    if len(argv) == 3 and argv[0] == "resolve-manifest":
        return resolve_manifest(argv[1], argv[2])
    if argv and argv[0] == "unshipped":
        status = unshipped(argv[1:])
        if status != 64:
            return status
    if len(argv) == 3 and argv[0] == "merged-url":
        return merged_url(argv[1], argv[2])
    print(__doc__, file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
