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
# Non-destructive & update-safe — never overwrites your files:
#   - copilot-instructions.md: only a one-time Centsei reference is added;
#   - agents.config.yml: created on first install, preserved on every re-run;
#   - agents, scripts and centsei-instructions.md are refreshed (Centsei-owned).
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"
VERSION="$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "dev")"

DRY_RUN=0
TARGET=""

usage() { sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

# ── Prerequisite helpers ──
detect_pkg_mgr() {
  if command -v brew    >/dev/null 2>&1; then echo brew
  elif command -v apt-get >/dev/null 2>&1; then echo apt
  elif command -v dnf   >/dev/null 2>&1; then echo dnf
  elif command -v pacman >/dev/null 2>&1; then echo pacman
  else echo unknown; fi
}
pkg_name() {  # pkg_name <mgr> <tool> → package name for that manager
  case "$2:$1" in
    rg:*)          echo ripgrep ;;
    fd:apt|fd:dnf) echo fd-find ;;
    fd:*)          echo fd ;;
    *)             echo "$2" ;;
  esac
}

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

# ── Check prerequisites (tools the agents rely on at runtime) ──
echo "Prerequisites:"
missing=""
for t in rg fd jq git; do
  if command -v "$t" >/dev/null 2>&1; then
    echo "  ✓ $t"
  else
    echo "  ✗ $t  (required — missing)"
    missing="$missing $t"
  fi
done
command -v sg      >/dev/null 2>&1 && echo "  ✓ sg (ast-grep, optional)"  || echo "  • sg (ast-grep, optional — structural search off)"
command -v copilot >/dev/null 2>&1 && echo "  ✓ copilot CLI"              || echo "  • copilot CLI not found — install it to run /agent centsei"
if [ -n "$missing" ]; then
  mgr=$(detect_pkg_mgr)
  pkgs=""
  for t in $missing; do pkgs="$pkgs $(pkg_name "$mgr" "$t")"; done
  echo
  echo "  ⚠ Install the missing required tools:"
  case "$mgr" in
    brew)   echo "      brew install$pkgs" ;;
    apt)    echo "      sudo apt-get install -y$pkgs"
            echo "      (Debian/Ubuntu: the 'fd' binary is 'fdfind' from the fd-find package)" ;;
    dnf)    echo "      sudo dnf install -y$pkgs" ;;
    pacman) echo "      sudo pacman -S$pkgs" ;;
    *)      echo "      via your package manager:$pkgs" ;;
  esac
fi
echo

# ── Copy Centsei-owned files (agents, scripts, centsei-instructions.md) ──
# agents.config.yml is YOUR file → handled separately below (never clobbered).
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
  [ "$rel" = ".github/agents.config.yml" ] && continue   # user file — handled below
  copy "$f" "$TARGET/$rel"
done < <(find "$TEMPLATE_DIR" -type f -print0)

# ── agents.config.yml: create on first install, PRESERVE on update ──
CFG="$TARGET/.github/agents.config.yml"
if [ -f "$CFG" ]; then
  echo "  = $CFG (kept your config — update preserves it)"
  echo "    new options? diff against $TEMPLATE_DIR/.github/agents.config.yml"
else
  echo "  + $CFG (created — edit it for your stack)"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$CFG")"
    cp "$TEMPLATE_DIR/.github/agents.config.yml" "$CFG"
  fi
fi

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
[ -n "$missing" ] && echo "  0. Install the missing prerequisites shown above"
echo "  1. Edit   $TARGET/.github/agents.config.yml  (stack, budget, allowed models)"
echo "  2. Launch Copilot CLI in the repo:  copilot  then  /agent centsei"
echo "  3. Usage details: see the framework's README.md"
