#!/usr/bin/env bash
#
# Vérification Swift complète sous Linux, sans Xcode.
#
#   1. parse      — syntaxe de TOUS les fichiers .swift (swift-frontend -parse)
#   2. typecheck  — typage de la couche non-UI (fichiers sans import SwiftUI)
#   3. tests      — émission du module « MyApp » + type-check de MyAppTests
#   4. lint       — SwiftLint (style + règles sémantiques)
#
# La couche SwiftUI (Views/, MyAppApp.swift) ne peut PAS être typée ici :
# le SDK Apple n'existe pas sur Linux. Elle est parsée, et typée sur Mac.
#
# Usage : bash scripts/swift-check.sh [--parse-only]
#
set -uo pipefail

PARSE_ONLY="${1:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# --- environnement ----------------------------------------------------------

# 1. Toolchain : soit l'installation locale, soit celle du PATH (CI/conteneur).
if [ -x "${SWIFT_HOME:-$HOME/.local/share/swift}/usr/bin/swiftc" ]; then
  SWIFT_HOME="${SWIFT_HOME:-$HOME/.local/share/swift}"
  SWIFT_BIN="$SWIFT_HOME/usr/bin"
elif command -v swiftc >/dev/null 2>&1; then
  SWIFT_BIN="$(cd "$(dirname "$(command -v swiftc)")" && pwd)"
  SWIFT_HOME="$(dirname "$SWIFT_BIN")/.."
else
  echo "✗ Toolchain Swift introuvable."
  echo "  Voir README.md, section « Toolchain Swift sous Linux »."
  exit 2
fi

SWIFTLINT="${SWIFTLINT:-$HOME/.local/bin/swiftlint}"

# 2. Image dégradée (Firebase Studio) : /usr/include est vide, il faut
#    pointer les headers glibc/noyau du store Nix et forcer le module map.
GLIBC_DEV="${GLIBC_DEV:-/nix/store/1v9ggwkpb0xy708s11s1g9fhinn3b06r-glibc-2.40-66-dev}"
LINUX_HEADERS="${LINUX_HEADERS:-/nix/store/20ggf4ik2s3wpkv6ngylc9f0ffpr10jx-linux-headers-6.2}"
MODULE_MAP="$SWIFT_HOME/usr/lib/swift/linux/x86_64/glibc.modulemap"
NIX_ENV=0
[ -d "$GLIBC_DEV/include" ] && NIX_ENV=1

OUT_DIR="build/linux-check"
mkdir -p "$OUT_DIR"

XCC=()
if [ "$NIX_ENV" -eq 1 ]; then
  [ ! -f "$MODULE_MAP" ] && { echo "✗ Module map Glibc introuvable : $MODULE_MAP"; exit 2; }

  # `textual header "assert.h"` se résout relativement au module map.
  if [ ! -e "$SWIFT_HOME/usr/lib/swift/linux/x86_64/assert.h" ] \
     && [ -f "$GLIBC_DEV/include/assert.h" ]; then
    ln -sf "$GLIBC_DEV/include/assert.h" "$SWIFT_HOME/usr/lib/swift/linux/x86_64/assert.h"
  fi

  [ -d "$SWIFT_HOME/shim-include" ] && XCC+=(-Xcc -isystem -Xcc "$SWIFT_HOME/shim-include")
  XCC+=(-Xcc -isystem -Xcc "$GLIBC_DEV/include")
  [ -d "$LINUX_HEADERS/include" ] && XCC+=(-Xcc -isystem -Xcc "$LINUX_HEADERS/include")
  XCC+=(-Xcc -fmodule-map-file="$MODULE_MAP")
fi

# Libs système manquantes sur cette image (ncurses/tinfo/sqlite/uuid),
# satisfaites par des liens vers le store Nix — voir README.
if [ -d "$SWIFT_HOME/lib-deps" ]; then
  export LD_LIBRARY_PATH="$SWIFT_HOME/lib-deps${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

NOISE="warning: libc not found for 'x86_64-unknown-linux-gnu'"

FAILURES=0
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }
pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

# run <label> <cmd...> : exécute, affiche le diagnostic si échec.
run() {
  local label="$1"
  shift
  local raw status
  raw="$("$@" 2>&1)"
  status=$?
  if [ "$status" -ne 0 ]; then
    fail "$label"
    printf '%s\n' "$raw" | grep -v "$NOISE" | sed 's/^/       /' | head -30
    return 1
  fi
  return 0
}

# --- inventaire -------------------------------------------------------------

mapfile -t ALL_SWIFT < <(find MyApp MyAppTests MyAppUITests -name '*.swift' | sort)

mapfile -t UI_SOURCES < <(grep -l '^import SwiftUI' "${ALL_SWIFT[@]}" | sort)

mapfile -t APP_TYPED < <(
  find MyApp -name '*.swift' | xargs grep -L '^import SwiftUI' | sort
)

mapfile -t TEST_SOURCES < <(find MyAppTests -name '*.swift' | sort)

# --- 1. syntaxe -------------------------------------------------------------

step "1/4  Syntaxe — ${#ALL_SWIFT[@]} fichier(s)"
SYNTAX_ERRORS=0
for file in "${ALL_SWIFT[@]}"; do
  raw="$("$SWIFT_BIN/swift-frontend" -parse -swift-version 5 "${XCC[@]}" "$file" 2>&1)"
  if [ $? -ne 0 ]; then
    SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fail "$file"
    printf '%s\n' "$raw" | grep -v "$NOISE" | sed 's/^/       /' | head -15
  fi
done
if [ "$SYNTAX_ERRORS" -eq 0 ]; then
  pass "aucune erreur de syntaxe — dont ${#UI_SOURCES[@]} fichier(s) SwiftUI"
fi

if [ -n "$PARSE_ONLY" ]; then
  echo
  [ "$FAILURES" -eq 0 ] && exit 0 || exit 1
fi

# --- 2. type-check de la couche non-UI --------------------------------------

step "2/4  Type-check — ${#APP_TYPED[@]} fichier(s) sans SwiftUI"
if run "erreurs de type dans la couche non-UI" \
     "$SWIFT_BIN/swiftc" -typecheck -swift-version 5 "${XCC[@]}" "${APP_TYPED[@]}"; then
  pass "modèle, magasin et ViewModel typés sans erreur"
fi

# --- 3. tests unitaires -----------------------------------------------------

step "3/4  Tests unitaires — ${#TEST_SOURCES[@]} fichier(s)"
if run "échec de l'émission du module MyApp" \
     "$SWIFT_BIN/swiftc" -emit-module -enable-testing -module-name MyApp \
     -emit-module-path "$OUT_DIR/MyApp.swiftmodule" "${XCC[@]}" "${APP_TYPED[@]}"; then
  if run "erreurs de type dans MyAppTests" \
       "$SWIFT_BIN/swiftc" -typecheck -swift-version 5 -I "$OUT_DIR" \
       "${XCC[@]}" "${TEST_SOURCES[@]}"; then
    pass "tests typés contre le module MyApp (XCTest Linux)"
  fi
fi

# --- 4. lint ----------------------------------------------------------------

step "4/4  SwiftLint"
if [ -x "$SWIFTLINT" ]; then
  # stdout = violations, stderr = avertissements (SourceKit absent sous Linux).
  lint_stdout="$OUT_DIR/lint.out"
  lint_stderr="$OUT_DIR/lint.err"
  "$SWIFTLINT" lint --quiet --reporter emoji >"$lint_stdout" 2>"$lint_stderr"

  if [ -s "$lint_stdout" ]; then
    cat "$lint_stdout"
    fail "SwiftLint : violations à corriger"
  else
    pass "SwiftLint : 0 violation"
  fi
  if [ -s "$lint_stderr" ]; then
    sed 's/^/       • /' "$lint_stderr"
  fi
else
  printf '  \033[33m⚠\033[0m SwiftLint absent (%s) — étape ignorée\n' "$SWIFTLINT"
fi

# --- résumé -----------------------------------------------------------------

echo
if [ "$FAILURES" -eq 0 ]; then
  printf '  \033[32m✓ Tout est vert.\033[0m\n'
  printf '    Couche SwiftUI non typée ici (pas de SDK Apple sur Linux) : ⌘R / ⌘U sur Mac.\n\n'
  exit 0
fi

printf '  \033[31m✗ %d étape(s) en échec.\033[0m\n\n' "$FAILURES"
exit 1
