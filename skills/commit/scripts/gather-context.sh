#!/usr/bin/env bash
set -euo pipefail

MAX_DIFF_LINES=${MAX_DIFF_LINES:-400}

branch=$(git rev-parse --abbrev-ref HEAD)
echo "== BRANCH =="
echo "$branch"

echo
echo "== JIRA KEY (from branch, verify before use) =="
key=$( (printf '%s\n' "$branch" | grep -oE '[A-Za-z]+-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]') || true)
echo "${key:-none}"

echo
echo "== STATUS =="
git status --short

echo
echo "== LOG (last 5) =="
git log -5 --oneline

print_diff() {
  local label=$1
  shift
  echo
  echo "== $label =="
  local diff lines
  diff=$(git diff "$@")
  if [ -z "$diff" ]; then
    echo "(empty)"
    return
  fi
  lines=$(printf '%s\n' "$diff" | wc -l | tr -d ' ')
  if [ "$lines" -gt "$MAX_DIFF_LINES" ]; then
    git diff --stat "$@"
    echo "-- diff truncated: first $MAX_DIFF_LINES of $lines lines --"
    printf '%s\n' "$diff" | head -n "$MAX_DIFF_LINES"
  else
    printf '%s\n' "$diff"
  fi
}

print_diff "STAGED DIFF" --cached
print_diff "UNSTAGED DIFF"
