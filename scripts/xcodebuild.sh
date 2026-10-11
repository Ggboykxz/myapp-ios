#!/usr/bin/env bash
#
# xcodebuild avec un destination automatique : n'importe quel Mac, sans
# avoir à deviner le nom du simulateur installé.
#
# Usage : bash scripts/xcodebuild.sh [build|test|clean]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ACTION="${1:-build}"
PROJECT="MyApp.xcodeproj"
SCHEME="MyApp"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "✗ xcodebuild introuvable : cette commande exige macOS + Xcode."
  echo "  Sur Linux, utilisez : npm run validate  /  npm run check"
  exit 2
fi

if [ "$ACTION" = "clean" ]; then
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" clean
  rm -rf build DerivedData
  exit 0
fi

# Destination : premier simulateur iPhone disponible.
SIMULATOR="$(xcrun simctl list devices available \
  | grep -E 'iPhone [0-9]+' \
  | head -1 \
  | sed -E 's/^ *(.*)( \(.*\))$/\1/' \
  | sed 's/ *$//')"

if [ -z "$SIMULATOR" ]; then
  echo "✗ Aucun simulateur iPhone disponible."
  echo "  Installez-en un depuis Xcode → Settings → Platforms."
  exit 1
fi

DESTINATION="platform=iOS Simulator,name=$SIMULATOR"
echo "→ destination : $DESTINATION"

if [ "$ACTION" = "test" ]; then
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination "$DESTINATION" -configuration Debug test
else
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination "$DESTINATION" -configuration Debug build
fi
