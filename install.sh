#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Centsei — installer
#
# Deploys the framework (agents, caveman scripts, config, Centsei rules)
# into a target repo.
#
# Usage:
#   ./install.sh                 # installs into the current repo
#   ./install.sh /path/repo      # installs into a specific repo
#   ./install.sh --dry-run       # shows what would be done, without writing
#   ./install.sh --help
#
# Non-destructive: never overwrites copilot-instructions.md — it only adds a
# one-time reference to .github/centsei-instructions.md (creating the file if absent).
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"
VERSION="$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "dev")"

DRY_RUN=0
TARGET=""

usage() { sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

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

# ── Back up agents.config.yml if it already exists (it gets overwritten) ──
EXISTING_CFG="$TARGET/.github/agents.config.yml"
if [ -f "$EXISTING_CFG" ] && [ "$DRY_RUN" -eq 0 ]; then
  cp "$EXISTING_CFG" "$EXISTING_CFG.bak.$(date +%Y%m%d%H%M%S)"
  echo "↳ Backed up existing agents.config.yml"
fi

# ── Copy template files (agents, config, scripts, centsei-instructions.md) ──
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

# ── Reference Centsei from copilot-instructions.md (idempotent, non-destructive) ──
CI="$TARGET/.github/copilot-instructions.md"
REF_SENTINEL='<!-- centsei:ref -->'
print_ref() {
  cat <<'REF'

<!-- centsei:ref -->
> **Centsei orchestration** — this repo is tooled by Centsei (github.com/maximebriand/Centsei).
> See [`.github/centsei-instructions.md`](centsei-instructions.md) for the credit-frugal
> multi-agent rules. Entry point: `/agent centsei`. Config: `.github/agents.config.yml`.
REF
}
if [ ! -f "$CI" ]; then
  echo "  + $CI (created with Centsei reference)"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$CI")"
    { printf '# Copilot instructions\n'; print_ref; } > "$CI"
  fi
elif grep -qF "$REF_SENTINEL" "$CI"; then
  echo "  = $CI (Centsei reference already present)"
else
  echo "  ~ $CI (Centsei reference appended — your content preserved)"
  if [ "$DRY_RUN" -eq 0 ]; then
    cp "$CI" "$CI.bak.$(date +%Y%m%d%H%M%S)"
    print_ref >> "$CI"
  fi
fi

echo
echo "✓ Installed."
echo
echo "Next steps:"
echo "  1. Edit   $TARGET/.github/agents.config.yml  (stack, budget, allowed models)"
echo "  2. Check that ripgrep (rg), fd and jq are installed on the machine/runner"
echo "  3. Launch Copilot CLI in the repo:  copilot  then  /agent centsei"
echo "  4. Usage details: see the framework's README.md"
