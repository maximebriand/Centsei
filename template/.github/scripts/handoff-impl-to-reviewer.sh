#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Caveman hand-off: implementer → reviewer, zero model calls.
# The diff passes through a file, not through a model-generated summary.
#
# Usage: handoff-impl-to-reviewer.sh [scope_path] [max_lines]
# Output (stdout): contract JSON consumable by the reviewer.
# Return code: 0 ready / 0 nothing to review / 1 diff too large (to split).
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

SCOPE="${1:-.}"
MAX_LINES="${2:-500}"
OUT_DIR="${TMPDIR:-/tmp}"

# 1. Nothing to review?
CHANGED=$(git diff --name-only HEAD -- "$SCOPE" | wc -l | tr -d ' ')
if [ "$CHANGED" -eq 0 ]; then
  echo '{"status":"nothing_to_review"}'
  exit 0
fi

# 2. Size guardrail: a huge diff is expensive to review → we request a split.
LINES=$(git diff HEAD -- "$SCOPE" | wc -l | tr -d ' ')
if [ "$LINES" -gt "$MAX_LINES" ]; then
  printf '{"status":"diff_too_large","lines":%s,"action":"split_task"}\n' "$LINES"
  exit 1
fi

# 3. Writes the patch to disk; the reviewer will read it via `git diff` or this file.
PATCH="$OUT_DIR/review_target.patch"
git diff HEAD -- "$SCOPE" > "$PATCH"
printf '{"status":"ready","patch":"%s","lines":%s}\n' "$PATCH" "$LINES"
