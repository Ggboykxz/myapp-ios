#!/usr/bin/env bash
#
# SwiftLint, quel que soit l'endroit où il est installé :
#   - brew (macOS) / PATH système
#   - binaire statique téléchargé sous ~/.local/bin (Linux)
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

LINT="${SWIFTLINT:-}"
if [ -z "$LINT" ]; then
  if command -v swiftlint >/dev/null 2>&1; then
    LINT="swiftlint"
  elif [ -x "$HOME/.local/bin/swiftlint" ]; then
    LINT="$HOME/.local/bin/swiftlint"
  else
    echo "• SwiftLint absent — ignoré."
    echo "  macOS : brew install swiftlint"
    echo "  Linux : voir README.md, section « Toolchain Swift sous Linux »."
    exit 0
  fi
fi

# stdout = violations, stderr = avertissements (SourceKit indisponible sous Linux).
tmp_out="$(mktemp)"
tmp_err="$(mktemp)"
"$LINT" lint --quiet --reporter emoji >"$tmp_out" 2>"$tmp_err"
status=0

if [ -s "$tmp_out" ]; then
  cat "$tmp_out"
  status=1
fi
[ -s "$tmp_err" ] && sed 's/^/• /' "$tmp_err"

rm -f "$tmp_out" "$tmp_err"
[ "$status" -eq 0 ] && echo "✓ SwiftLint : 0 violation"
exit "$status"
