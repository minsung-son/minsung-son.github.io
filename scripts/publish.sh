#!/bin/bash
# Commit and push, then wait for the GitHub Pages build and report the result.
#
#   scripts/publish.sh "<commit message>" [path ...]
#
# With no paths, everything under _articles/ and about/ is staged.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
MSG="${1:-Update articles}"; shift || true
REPO="minsung-son/minsung-son.github.io"

python3 scripts/check-article.py "$@" >/dev/null 2>&1 || {
  echo "check-article.py found errors. Fix them first:"; python3 scripts/check-article.py "$@"; exit 1; }

if [[ $# -gt 0 ]]; then git add -- "$@"; else git add -- _articles about; fi
if git diff --cached --quiet; then echo "Nothing to commit."; exit 0; fi
git -c core.quotepath=false diff --cached --stat | tail -20
git commit -q -m "$MSG"
git push -q origin main
SHA=$(git rev-parse HEAD)
echo "Pushed $SHA. Waiting for GitHub Pages build..."

for i in $(seq 1 40); do
  sleep 20
  json=$(curl -s "https://api.github.com/repos/$REPO/actions/runs?branch=main&per_page=3")
  state=$(printf '%s' "$json" | python3 -c "
import sys, json
runs = json.load(sys.stdin).get('workflow_runs', [])
r = next((r for r in runs if r['head_sha'] == '$SHA'), None)
print(f\"{r['status']} {r['conclusion'] or ''} {r['html_url']}\" if r else 'pending')" 2>/dev/null || echo "unknown")
  echo "  [$((i*20))s] $state"
  case "$state" in
    completed\ success*) echo "Build succeeded. Site updates within a couple of minutes: https://minsung-son.github.io"; exit 0 ;;
    completed\ *) echo "BUILD FAILED. Log: ${state##* }"; exit 1 ;;
  esac
done
echo "Timed out waiting; check https://github.com/$REPO/actions"
