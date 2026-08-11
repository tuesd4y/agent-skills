#!/usr/bin/env bash
set -uo pipefail

MAX_DIFF_LINES=${MAX_DIFF_LINES:-400}

branch=$(git rev-parse --abbrev-ref HEAD)
echo "== BRANCH =="
echo "$branch"

echo
echo "== JIRA KEY (from branch, verify before use) =="
key=$( (printf '%s\n' "$branch" | grep -oE '[A-Za-z]+-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]') || true)
echo "${key:-none}"

echo
echo "== UNCOMMITTED CHANGES =="
uncommitted=$(git status --short)
echo "${uncommitted:-none}"

echo
echo "== BASE BRANCH =="
base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
if [ -z "$base" ] && command -v gh >/dev/null 2>&1; then
  base=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)
fi
if [ -z "$base" ]; then
  for candidate in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$candidate" || git show-ref --verify --quiet "refs/heads/$candidate"; then
      base=$candidate
      break
    fi
  done
fi
echo "${base:-unknown}"

echo
echo "== PUSH STATE =="
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
if [ -z "$upstream" ]; then
  echo "no upstream — branch not pushed yet"
else
  counts=$(git rev-list --left-right --count "$upstream...HEAD")
  behind=$(echo "$counts" | awk '{print $1}')
  ahead=$(echo "$counts" | awk '{print $2}')
  echo "upstream $upstream — $ahead ahead, $behind behind"
fi

if [ -n "$base" ]; then
  base_ref="origin/$base"
  git show-ref --verify --quiet "refs/remotes/origin/$base" || base_ref=$base
  merge_base=$(git merge-base "$base_ref" HEAD 2>/dev/null || true)

  echo
  echo "== COMMITS vs $base_ref =="
  if [ -n "$merge_base" ]; then
    commits=$(git log --oneline "$merge_base..HEAD")
    echo "${commits:-none}"

    echo
    echo "== DIFF STAT vs $base_ref =="
    git diff --stat "$merge_base..HEAD"

    echo
    echo "== DIFF vs $base_ref =="
    diff=$(git diff "$merge_base..HEAD")
    if [ -z "$diff" ]; then
      echo "(empty)"
    else
      lines=$(printf '%s\n' "$diff" | wc -l | tr -d ' ')
      if [ "$lines" -gt "$MAX_DIFF_LINES" ]; then
        echo "-- diff truncated: first $MAX_DIFF_LINES of $lines lines --"
        printf '%s\n' "$diff" | head -n "$MAX_DIFF_LINES"
      else
        printf '%s\n' "$diff"
      fi
    fi
  else
    echo "could not determine merge base with $base_ref"
  fi
fi

echo
echo "== PR TEMPLATES =="
found_template=0
for t in .github/PULL_REQUEST_TEMPLATE.md .github/pull_request_template.md PULL_REQUEST_TEMPLATE.md pull_request_template.md docs/PULL_REQUEST_TEMPLATE.md docs/pull_request_template.md; do
  if [ -f "$t" ]; then
    found_template=1
    echo "--- $t ---"
    cat "$t"
    echo
  fi
done
if [ -d .github/PULL_REQUEST_TEMPLATE ]; then
  for t in .github/PULL_REQUEST_TEMPLATE/*.md; do
    [ -f "$t" ] || continue
    found_template=1
    echo "--- $t ---"
    cat "$t"
    echo
  done
fi
[ "$found_template" -eq 0 ] && echo "none"

echo
echo "== EXISTING PR FOR BRANCH =="
if command -v gh >/dev/null 2>&1; then
  pr=$(gh pr view --json number,title,state,isDraft,url -q '"#\(.number) [\(.state)\(if .isDraft then ", draft" else "" end)] \(.title) — \(.url)"' 2>/dev/null || true)
  echo "${pr:-none}"
else
  echo "gh not available"
fi
