# MyApp — projet SwiftUI (iOS 17.0)

[![iOS](https://github.com/Ggboykxz/myapp-ios/actions/workflows/ios.yml/badge.svg)](https://github.com/Ggboykxz/myapp-ios/actions/workflows/ios.yml)

Projet iOS natif **SwiftUI**, prêt à ouvrir sur Mac. Le développement se fait
sur macOS (Xcode) ; cette machine (Linux) sert à écrire le code et à valider
la structure du projet.

| | |
|---|---|
| Framework | SwiftUI + Observation (`@Observable`) |
| Cible | iOS 17.0 minimum |
| Bundle ID | `com.example.myapp` |
| Langage | Swift 5 (mode classique, pas de Swift 6 strict) |
| Architecture | MVVM — Vue / ViewModel / Model / Store |
| Tests | XCTest unitaires + XCUITest |

## État de l'environnement

Cette machine est **Linux (Firebase Studio)** : pas de Xcode, pas de
simulateur iOS — un **build iOS natif y reste impossible**. En revanche, une
**toolchain Swift 6.2 + SwiftLint** y est installée : le code est parsé,
typé et linté ici. Seule la couche SwiftUI échappe au typage (SDK Apple
absent).

| Vérification | Commande | Ici | Sur Mac |
|---|---|---|---|
| Structure `.pbxproj`, assets, schéma | `npm run validate` | ✅ | ✅ |
| Syntaxe des 11 fichiers Swift | `npm run parse` | ✅ | ✅ |
| Type-check modèle / magasin / ViewModel | `npm run check` | ✅ | ✅ |
| Tests unitaires typés (module `MyApp`) | `npm run check` | ✅ | ✅ |
| SwiftLint (style + règles) | `npm run lint` | ✅ | ✅ |
| Type-check des vues SwiftUI | — | ❌ | ✅ Xcode |
| Compilation, simulateur, XCUITest | `npm run build` / `npm test` | ❌ | ✅ |

CI GitHub Actions (`.github/workflows/ios.yml`) : `validate` + `lint` +
`swift-check` sur Linux, puis `build-and-test` sur runner `macos-15`.
Dépôt : <https://github.com/Ggboykxz/myapp-ios> — tout push sur `main`
déclenche les 4 jobs ; `build-and-test` (macOS) démarre seulement si les 3
jobs Linux sont verts.

Sur Mac, il faut : **Xcode 15 ou +**, un compte Apple Developer (gratuit
suffit pour le simulateur).

## Démarrage (Mac)

```bash
open MyApp.xcodeproj     # ou `make open`
# puis ⌘R pour lancer, ⌘U pour les tests
```

En ligne de commande :

```bash
npm run validate   # structure du projet (rapide, sans toolchain)
npm run check      # structure + syntaxe + type-check + tests + lint
npm run lint       # SwiftLint seul
npm run build      # xcodebuild build  (macOS)
npm test           # xcodebuild test   (macOS)
```

Mêmes cibles en `make validate|check|build|test` — mais `make` n'est pas
installé sur cette machine, d'où les commandes `npm` par défaut.

> `scripts/xcodebuild.sh` choisit automatiquement le premier simulateur
> iPhone disponible (`xcrun simctl list devices available`) : plus besoin de
> deviner le nom exact.

## Toolchain Swift sous Linux

Réinstallable de zéro sur une image similaire (étapes réellement
appliquées ici, Swift 6.2 / Ubuntu 24.04) :

1. **Le binaire** — tarball officiel :
   ```bash
   mkdir -p ~/.local/share/swift
   curl -fL https://download.swift.org/swift-6.2-release/ubuntu2404/swift-6.2-RELEASE/swift-6.2-RELEASE-ubuntu24.04.tar.gz \
     | tar -xz -C ~/.local/share/swift --strip-components=1
   ```
2. **4 libs système absentes** (`libncurses.so.6`, `libtinfo.so.6`,
   `libsqlite3.so.0`, `libuuid.so.1`) → liens symboliques dans
   `~/.local/share/swift/lib-deps/`, exposés par `LD_LIBRARY_PATH`
   (pris en charge automatiquement par `scripts/swift-check.sh`).
3. **En-têtes C absents** (`/usr/include` est vide sur cette image) →
   `glibc-2.40-66-dev` et `linux-headers-6.2` du store Nix, passés en
   `-Xcc -isystem`.
4. **Module map `SwiftGlibc`** non transmis par le driver → forcé avec
   `-Xcc -fmodule-map-file`, `assert.h` lié à côté (un `textual header` se
   résout relativement au module map).
5. **`<tgmath.h>`** → glibc 2.40 refuse l'association clang ↔ édition GCC
   4.2.1 : un shim vide en tête de path contourne le problème, sans incidence
   sur le typage Swift.
6. **SwiftLint** → `swiftlint_linux_amd64.zip` (0.65.1) dans
   `~/.local/bin` : utiliser le binaire **`swiftlint-static`**, l'autre
   réclame `libcurl.so.4`, absent ici.

Sur une Ubuntu standard, **aucune de ces étapes n'est nécessaire** :
`scripts/swift-check.sh` détecte l'environnement et n'ajoute que le
strict nécessaire.

## Arborescence

```
.
├── MyApp.xcodeproj/          # projet Xcode (schéma partagé compris)
│   └── xcshareddata/xcschemes/MyApp.xcscheme
├── MyApp/
│   ├── MyAppApp.swift        # point d'entrée, injection du ViewModel
│   ├── Views/                # SwiftUI : ContentView, ItemRow, ItemDetailView, NewItemSheet
│   ├── ViewModels/           # ItemListViewModel (@Observable, testable sans UI)
│   ├── Models/               # Item (Codable, Hashable)
│   ├── Services/             # ItemStore (protocole) + InMemory / JSONFile
│   ├── Support/              # Theme (constantes visuelles)
│   ├── Assets.xcassets/      # AppIcon + AccentColor
│   └── Preview Content/      # assets réservés aux previews
├── MyAppTests/               # tests unitaires du ViewModel
├── MyAppUITests/             # scénarios XCUITest
├── project.yml               # définition XcodeGen (fallback, optionnel)
├── scripts/
│   ├── validate-project.mjs  # parseur pbxproj + cohérence sources/assets
│   ├── swift-check.sh        # parse + type-check + tests + lint
│   ├── lint.sh               # SwiftLint, quel que soit son emplacement
│   └── xcodebuild.sh         # build/test avec destination auto (macOS)
├── package.json              # `npm run validate|check|parse|lint|build|test`
├── Makefile                  # mêmes cibles en make (macOS)
├── .github/workflows/ios.yml # CI : validate + lint + swift-check (Linux) → build/test (macOS)
├── .swiftlint.yml            # config SwiftLint
└── .editorconfig
```

## Fonctionnement

`ItemListViewModel` expose un état observable (`items`, `filter`,
`searchText`, `loadState`) et reçoit les intentions (`load`, `addItem`,
`toggle`, `delete`). Les vues lisent l'état via
`@Environment(ItemListViewModel.self)` et passent par `Bindable` pour les
liens (`$model.filter`, `$model.searchText`).

La persistance passe par le protocole `ItemStore` :

- `InMemoryItemStore` — previews et tests ;
- `JSONFileItemStore` — fichier `items.json` dans Application Support,
  encodage ISO-8601, écriture atomique.

Ajouter un écran : créer le fichier dans `MyApp/Views/`, **puis l'ajouter à la
cible** (clic droit sur le groupe → *Add Files to "MyApp"*). Vérifier ensuite
avec `npm run validate` : un fichier absent du `.pbxproj` y serait signalé.

## Renommer l'app

1. `PRODUCT_BUNDLE_IDENTIFIER` (2 occurrences : app + tests) dans le pbxproj.
2. `name:` et `targets:` dans `project.yml` (si XcodeGen est utilisé).
3. Schéma : clic sur le schéma → *Edit Scheme* → renommer.
4. `navigationTitle("MyApp")` dans `ContentView.swift`.
5. Cible `MyAppTests` : garder `@testable import MyApp` aligné sur le module.

## Options

- **XcodeGen** (régénérer le projet au lieu d'éditer le pbxproj) :
  `brew install xcodegen && xcodegen generate`.
- **SwiftLint** : `brew install swiftlint` — la config est déjà en place.
- **App icon** : déposer `AppIcon.png` (1024×1024) dans
  `MyApp/Assets.xcassets/AppIcon.appiconset/` et ajouter le champ
  `"filename"` dans son `Contents.json` (l'absence d'icône n'empêche pas de
  builder, Xcode émet simplement un avertissement).

## Limites connues de cette machine

- **La couche SwiftUI n'est pas typée ici** (pas de SDK Apple sur Linux) :
  les vues sont parsées (SwiftLint les lit avec swift-syntax) et relues, mais
  `@Bindable`, les modificateurs et les APIs iOS 17 ne sont vérifiés qu'à
  l'ouverture sous Xcode. Tout le reste — modèle, magasin, ViewModel, tests —
  est typé pour de bon.
- **Signature** : `CODE_SIGN_STYLE = Automatic` et `DEVELOPMENT_TEAM = ""`
  (6 occurrences dans le pbxproj, recherchez `DEVELOPMENT_TEAM`). C'est la
  configuration **simulateur** : renseigner l'équipe dans *Signing &
  Capabilities* avant tout dépôt sur un appareil physique.
- **`com.example.myapp`** est un identifiant fictif : à remplacer avant tout
  dépôt sur l'App Store.
- **App icon absente** : build accepté, avertissement Xcode à la compilation.
