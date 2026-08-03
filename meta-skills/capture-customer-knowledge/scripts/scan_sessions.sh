#!/usr/bin/env bash
# List recent Claude Code sessions, or dump one as readable text.
#
# Transcripts are large (hundreds of KB of JSONL, most of it tool output).
# --extract strips them to the conversation so a scan does not have to load
# raw JSONL into context.
set -euo pipefail

usage() {
  cat <<'EOF'
Inspect recent Claude Code session transcripts.

Usage:
  scan_sessions.sh --list [--count N] [--project SUBSTRING]
  scan_sessions.sh --extract SESSION [--max-chars N]

Modes:
  --list              Most recent sessions, newest first (default count: 3)
  --extract SESSION   Dump one session as readable text. SESSION is a session
                      id, a transcript path, or a list index from --list.

Options:
  --count N           How many sessions to list (default: 3)
  --project SUBSTRING Only sessions whose project path contains SUBSTRING
  --max-chars N       Truncate each assistant message (default: 600)
  -h, --help          Show this help

Environment: CLAUDE_PROJECTS_DIR (default: ~/.claude/projects)
EOF
}

mode=""
count=3
project_filter=""
session=""
max_chars=600

while (($#)); do
  case "$1" in
    --list)
      mode="list"
      shift
      ;;
    --extract)
      mode="extract"
      session="${2:-}"
      shift 2
      ;;
    --count)
      count="${2:-}"
      shift 2
      ;;
    --project)
      project_filter="${2:-}"
      shift 2
      ;;
    --max-chars)
      max_chars="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

projects_dir="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"

[[ -n "$mode" ]] || { echo "error: --list or --extract is required" >&2; usage >&2; exit 2; }
[[ -d "$projects_dir" ]] || { echo "error: no transcripts at $projects_dir" >&2; exit 2; }
[[ "$count" =~ ^[1-9][0-9]*$ ]] || { echo "error: --count must be a positive integer" >&2; exit 2; }
[[ "$max_chars" =~ ^[1-9][0-9]*$ ]] || { echo "error: --max-chars must be a positive integer" >&2; exit 2; }
command -v python3 >/dev/null || { echo "error: python3 not found" >&2; exit 2; }

MODE="$mode" COUNT="$count" PROJECT_FILTER="$project_filter" \
SESSION="$session" MAX_CHARS="$max_chars" PROJECTS_DIR="$projects_dir" \
python3 <<'PY'
import json
import os
import sys
from pathlib import Path

projects_dir = Path(os.environ["PROJECTS_DIR"])
mode = os.environ["MODE"]
count = int(os.environ["COUNT"])
project_filter = os.environ["PROJECT_FILTER"]
session_arg = os.environ["SESSION"]
max_chars = int(os.environ["MAX_CHARS"])


def read_lines(path):
    with path.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def summarize(path):
    """Cheap metadata pass: project, branch, title, turn count, first prompt."""
    info = {
        "path": path,
        "session": path.stem,
        "cwd": "",
        "branch": "",
        "title": "",
        "turns": 0,
        "first_prompt": "",
        "mtime": path.stat().st_mtime,
    }
    for record in read_lines(path):
        kind = record.get("type")
        if kind == "ai-title" and not info["title"]:
            info["title"] = record.get("aiTitle", "")
        elif kind in ("user", "assistant"):
            info["cwd"] = info["cwd"] or record.get("cwd", "")
            info["branch"] = info["branch"] or record.get("gitBranch", "")
            if kind == "user":
                info["turns"] += 1
                if not info["first_prompt"]:
                    text = flatten(record.get("message", {}).get("content"))
                    info["first_prompt"] = " ".join(text.split())[:120]
    return info


def flatten(content):
    """Message content is either a string or a list of typed blocks."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    parts = []
    for block in content:
        if not isinstance(block, dict):
            continue
        kind = block.get("type")
        if kind == "text":
            parts.append(block.get("text", ""))
        elif kind == "tool_use":
            target = block.get("input", {})
            hint = ""
            for key in ("file_path", "command", "pattern", "url", "path"):
                if key in target:
                    hint = str(target[key])[:120]
                    break
            parts.append(f"[tool: {block.get('name', '?')}{' ' + hint if hint else ''}]")
        elif kind == "tool_result":
            # Tool output is the bulk of a transcript and is rarely the place a
            # durable fact is stated. Keep only failures.
            if block.get("is_error"):
                parts.append(f"[tool error: {flatten(block.get('content'))[:200]}]")
    return "\n".join(p for p in parts if p)


transcripts = sorted(
    projects_dir.glob("*/*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True
)
if not transcripts:
    sys.exit(f"error: no transcripts found under {projects_dir}")

if mode == "list":
    shown = 0
    for path in transcripts:
        if shown >= count:
            break
        info = summarize(path)
        if project_filter and project_filter not in info["cwd"]:
            continue
        if not info["turns"]:
            continue
        shown += 1
        from datetime import datetime

        when = datetime.fromtimestamp(info["mtime"]).strftime("%Y-%m-%d %H:%M")
        print(f"[{shown}] {info['session']}")
        print(f"    project : {info['cwd'] or '?'}")
        print(f"    branch  : {info['branch'] or '?'}")
        print(f"    updated : {when}   turns: {info['turns']}")
        if info["title"]:
            print(f"    title   : {info['title']}")
        if info["first_prompt"]:
            print(f"    opened  : {info['first_prompt']}")
        print(f"    path    : {path}")
        print()
    if not shown:
        sys.exit("error: no sessions matched")
    sys.exit(0)

# --- extract ---------------------------------------------------------------
target = None
if session_arg.isdigit():
    index = int(session_arg)
    shown = 0
    for path in transcripts:
        info = summarize(path)
        if project_filter and project_filter not in info["cwd"]:
            continue
        if not info["turns"]:
            continue
        shown += 1
        if shown == index:
            target = path
            break
else:
    candidate = Path(session_arg)
    if candidate.is_file():
        target = candidate
    else:
        for path in transcripts:
            if path.stem == session_arg:
                target = path
                break

if target is None:
    sys.exit(f"error: could not resolve session {session_arg!r}")

info = summarize(target)
print(f"# Session {info['session']}")
print(f"# project: {info['cwd']}   branch: {info['branch']}")
if info["title"]:
    print(f"# title: {info['title']}")
print()

for record in read_lines(target):
    kind = record.get("type")
    if kind not in ("user", "assistant"):
        continue
    if record.get("isSidechain"):
        continue
    text = flatten(record.get("message", {}).get("content")).strip()
    if not text:
        continue
    if kind == "user":
        print(f"## USER\n{text}\n")
    else:
        if len(text) > max_chars:
            text = text[:max_chars] + f"... [+{len(text) - max_chars} chars]"
        print(f"## ASSISTANT\n{text}\n")
PY
