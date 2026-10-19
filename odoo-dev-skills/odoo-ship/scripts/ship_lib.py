#!/usr/bin/env python3
"""Helpers for ship.sh.

resolve-manifest PATH SHA
    Resolve a cherry-pick conflict in PATH that touches only the manifest
    `version` line. Keeps the checked-out (staging) side and bumps its version
    at the level commit SHA bumped, e.g. staging 18.0.2.10.0 + a minor bump ->
    18.0.2.11.0. Prints the new version. Exits 2 when the conflict is anything
    else, leaving the file untouched.

messages JSON BRANCH [--iterations]
    Print the commit messages of the merged PRs in JSON (`gh pr list --json
    headRefName,url,commits`) whose head is BRANCH, or with --iterations also
    BRANCH-<n>; separated by \x1e. Squash merges keep the original messages
    only there.

merged-url JSON BRANCH
    Print the URL of the first merged PR in JSON whose head is BRANCH.

picked REF SHA [KNOWN]
    Exit 0 when SHA's full message is already in REF's history or in KNOWN
    (output of `messages`), i.e. SHA was already shipped there. Exit 1
    otherwise. Whitespace is normalized, so rewrapping does not matter.
"""
import json
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


def messages(json_path, branch, iterations=False):
    for pr in matching_prs(json_path, branch, iterations):
        for commit in pr.get("commits", []):
            sys.stdout.write(pr_commit_message(commit) + "\x1e")
    return 0


def merged_url(json_path, branch):
    prs = matching_prs(json_path, branch)
    if prs:
        print(prs[0].get("url", ""))
    return 0


def picked(ref, sha, known_path=None):
    message = normalize(git("log", "-1", "--format=%B", sha))
    shipped = git("log", "--format=%B%x1e", "-n", "5000", ref).split("\x1e")
    if known_path:
        with open(known_path) as handle:
            shipped += handle.read().split("\x1e")
    return 0 if message in {normalize(m) for m in shipped} else 1


def main(argv):
    if len(argv) == 3 and argv[0] == "resolve-manifest":
        return resolve_manifest(argv[1], argv[2])
    if len(argv) in (3, 4) and argv[0] == "messages":
        return messages(argv[1], argv[2], argv[3:] == ["--iterations"])
    if len(argv) == 3 and argv[0] == "merged-url":
        return merged_url(argv[1], argv[2])
    if len(argv) in (3, 4) and argv[0] == "picked":
        return picked(*argv[1:])
    print(__doc__, file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
