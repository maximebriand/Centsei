#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Centsei — installer
#
# Deploys the framework (agents, caveman scripts, config) into a target repo.
#
# Usage:
#   ./install.sh                 # installs into the current repo
#   ./install.sh /path/repo      # installs into a specific repo
#   ./install.sh --dry-run       # shows what would be done, without writing anything
#   ./install.sh --help
#
# Idempotent: backs up any existing config before overwriting.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"
VERSION="$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "dev")"

DRY_RUN=0
TARGET=""

usage() { sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage ;;
    --dry-run) DRY_RUN=1 ;;
    -*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *) TARGET="$arg" ;;
  esac
done

TARGET="${TARGET:-$(pwd)}"

# ── Checks ──
[ -d "$TEMPLATE_DIR/.github" ] || { echo "✗ Template not found: $TEMPLATE_DIR" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "✗ Target repo not found: $TARGET" >&2; exit 1; }

echo "Centsei v$VERSION — master the art of credits"
echo "  source: $TEMPLATE_DIR"
echo "  target: $TARGET/.github/"
[ "$DRY_RUN" -eq 1 ] && echo "  mode  : DRY-RUN (no writes)"
echo

# ── Backup of existing files that would be overwritten ──
for rel in agents.config.yml copilot-instructions.md; do
  EXISTING="$TARGET/.github/$rel"
  if [ -f "$EXISTING" ] && [ "$DRY_RUN" -eq 0 ]; then
    BACKUP="$EXISTING.bak.$(date +%Y%m%d%H%M%S)"
    cp "$EXISTING" "$BACKUP"
    echo "↳ Existing file backed up: $BACKUP"
  fi
done

# ── Copy ──
copy() {
  local src="$1" dst="$2"
  echo "  + $dst"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  fi
}

while IFS= read -r -d '' f; do
  rel="${f#"$TEMPLATE_DIR"/}"
  copy "$f" "$TARGET/$rel"
done < <(find "$TEMPLATE_DIR" -type f -print0)

# ── Execute permissions on the caveman scripts ──
if [ "$DRY_RUN" -eq 0 ]; then
  chmod +x "$TARGET"/.github/scripts/*.sh 2>/dev/null || true
fi

echo
echo "✓ Installed."
echo
echo "Next steps:"
echo "  1. Edit   $TARGET/.github/agents.config.yml  (stack, budget, allowed models)"
echo "  2. Check that ripgrep (rg), fd and jq are installed on the machine/runner"
echo "  3. Launch Copilot CLI in the repo:  copilot  then  /agent centsei"
echo "  4. Usage details: see the framework's README.md"
