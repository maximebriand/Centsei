#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Caveman hand-off: deterministic pre-filter BEFORE the implementer.
# Reduces the surface to ~10 relevant files — zero model calls.
#
# Usage: prefilter-scope.sh "keywords" [root1 root2 ...]
# Output (stdout): JSON { "relevant_files": [...] }
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

KEYWORDS="${1:?Usage: prefilter-scope.sh \"keywords\" [roots...]}"
shift || true
ROOTS=("$@")
if [ "${#ROOTS[@]}" -eq 0 ]; then ROOTS=("."); fi

# fd lists candidate files; rg keeps only those that match;
# head caps at 10 to bound the downstream cost.
fd -t f -e ts -e tsx -e js -e py -e go -e java -e html . "${ROOTS[@]}" 2>/dev/null \
  | xargs -r rg -l --max-count 1 -F "$KEYWORDS" 2>/dev/null \
  | head -10 \
  | jq -R -s '{relevant_files: (split("\n") | map(select(. != "")))}'
